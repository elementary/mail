// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.AccountSourceItem : Mail.SourceList.ExpandableItem {
    public Mail.Backend.Account account { get; construct; }

    public signal void loaded ();

    private GLib.Cancellable connect_cancellable;
    private Gee.HashMap<string, FolderSourceItem> folder_items;
    private Gee.HashMap<string, Camel.Folder> folders;
    private AccountSavedState saved_state;
    private unowned Camel.OfflineStore offlinestore;

    public AccountSourceItem (Mail.Backend.Account account) {
        Object (account: account);
    }

    construct {
        visible = true;
        connect_cancellable = new GLib.Cancellable ();
        folder_items = new Gee.HashMap<string, FolderSourceItem> ();
        folders = new Gee.HashMap<string, Camel.Folder> ();
        saved_state = new AccountSavedState (account);
        saved_state.bind_with_expandable_item (this);

        offlinestore = (Camel.OfflineStore) account.service;
        name = offlinestore.display_name;
        offlinestore.folder_created.connect (folder_created);
        offlinestore.folder_deleted.connect (folder_deleted);
        offlinestore.folder_info_stale.connect (reload_folders);
        offlinestore.folder_renamed.connect (folder_renamed);
        unowned GLib.NetworkMonitor network_monitor = GLib.NetworkMonitor.get_default ();
        network_monitor.network_changed.connect (() =>{
            connect_to_account.begin ();
        });
    }

    ~AccountSourceItem () {
        connect_cancellable.cancel ();
    }

    public async void load () {
        try {
            var folderinfo = yield offlinestore.get_folder_info (null, Camel.StoreGetFolderInfoFlags.RECURSIVE, GLib.Priority.DEFAULT, connect_cancellable);
            if (folderinfo != null) {
                folder_created (folderinfo);
            }
        } catch (Error e) {
            critical (e.message);
        }

        connect_to_account.begin ();
    }

    private async void connect_to_account () {
        unowned GLib.NetworkMonitor network_monitor = GLib.NetworkMonitor.get_default ();
        if (network_monitor.network_available == false) {
            return;
        }

        try {
            yield offlinestore.set_online (true, GLib.Priority.DEFAULT, connect_cancellable);
            yield offlinestore.connect (GLib.Priority.DEFAULT, connect_cancellable);

            yield offlinestore.synchronize (false, GLib.Priority.DEFAULT, connect_cancellable);
        } catch (Error e) {
            critical (e.message);
        }
    }

    private void folder_renamed (string old_name, Camel.FolderInfo folder_info) {
        var item = folder_items[old_name];
        item.update_infos (folder_info);

        lock (folders) {
            if (folders.has_key (old_name)) {
                Camel.Folder folder;
                if (folders.unset (old_name, out folder)) {
                    folders.set (folder_info.full_name, folder);

                    folder.refresh_info.begin (GLib.Priority.DEFAULT, null);
                }
            }
        }
    }

    private void folder_deleted (Camel.FolderInfo folder_info) {
        Mail.FolderSourceItem? item = folder_items[folder_info.full_name];
        if (item != null) {
            item.parent.remove (item);
            folder_items.unset (folder_info.full_name);

            lock (folders) {
                folders.unset (folder_info.full_name);
            }
        }
    }

    private void folder_created (Camel.FolderInfo folder_info) {
        if (folder_info.parent == null) {
            show_info (folder_info, this);
            connect_folder_changed (folder_info);

        } else {
            unowned Camel.FolderInfo parent_info = (Camel.FolderInfo) folder_info.parent;
            var parent_item = folder_items[parent_info.full_name];
            if (parent_item == null) {
                // Create the parent, then retry to create the children.
                folder_created (parent_info);
                folder_created (folder_info);
            } else {
                show_info (folder_info, parent_item);
                connect_folder_changed (folder_info);
            }
        }
    }

    private void connect_folder_changed (Camel.FolderInfo folder_info) {
        offlinestore.get_folder.begin (folder_info.full_name, Camel.StoreGetFolderFlags.NONE, GLib.Priority.DEFAULT, null, (obj, res) => {
            try {
                var folder = offlinestore.get_folder.end (res);
                folder.changed.connect ((changes) => {
                    folder_changed (folder, changes);
                });

                lock (folders) {
                    folders.set (folder_info.full_name, folder);
                }

            } catch (Error e) {
                warning ("Error retrieving folder '%s' from store: %s", folder_info.full_name, e.message);
            }
        });
    }

    private void folder_changed (Camel.Folder folder, Camel.FolderChangeInfo changes) {
        Mail.FolderSourceItem? item = folder_items[folder.full_name];

        if (item != null && account.service is Camel.Store) {
            var store = (Camel.Store) account.service;

            store.get_folder_info.begin (folder.full_name, Camel.StoreGetFolderInfoFlags.REFRESH, GLib.Priority.DEFAULT, null, (obj, res) => {
                try {
                    var folder_info = store.get_folder_info.end (res);
                    item.update_infos (folder_info);

                } catch (Error e) {
                    warning ("Error refreshing folder info for '%s': %s", folder.full_name, e.message);
                }
            });
        }
    }

    private async void reload_folders () {
        var offlinestore = (Camel.OfflineStore) account.service;
        foreach (var folder_item in folder_items.values) {
            try {
                var folder_info = yield offlinestore.get_folder_info (folder_item.full_name, 0, GLib.Priority.DEFAULT, connect_cancellable);
                folder_item.update_infos (folder_info);
            } catch (Error e) {
                // We can cancel the operation
                if (!(e is GLib.IOError.CANCELLED)) {
                    critical (e.message);
                }
            }
        }
    }

    private void show_info (Camel.FolderInfo? _folderinfo, Mail.SourceList.ExpandableItem item) {
        var folderinfo = _folderinfo;
        while (folderinfo != null) {
            var folder_item = new FolderSourceItem (account, folderinfo);
            saved_state.bind_with_expandable_item (folder_item);
            folder_items[folderinfo.full_name] = folder_item;
            folder_item.refresh.connect (() => {
                refresh_folder.begin (folder_item.full_name);
            });

            if (folderinfo.child != null) {
                show_info ((Camel.FolderInfo?) folderinfo.child, folder_item);
            }

            item.add (folder_item);
            folderinfo = (Camel.FolderInfo?) folderinfo.next;
        }
    }

    private async void refresh_folder (string folder_name) {
        var offlinestore = (Camel.Store) account.service;
        try {
            var folder = yield offlinestore.get_folder (folder_name, 0, GLib.Priority.DEFAULT, connect_cancellable);
            yield folder.refresh_info (GLib.Priority.DEFAULT, connect_cancellable);
        } catch (Error e) {
            critical (e.message);
        }
    }
}
