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

public class Mail.AccountSourceItem : Mail.SourceList.ExpandableItem, Mail.SourceListSortable {
    public Mail.Backend.Account account { get; construct; }

    public signal void loaded ();
    public signal void start_edit (Mail.SourceList.Item item);

    private GLib.Cancellable connect_cancellable;
    private Gee.HashMap<string, FolderSourceItem> folder_items;
    private AccountSavedState saved_state;
    private unowned Camel.OfflineStore offlinestore;

    public AccountSourceItem (Mail.Backend.Account account) {
        Object (account: account);
    }

    construct {
        visible = true;
        connect_cancellable = new GLib.Cancellable ();
        folder_items = new Gee.HashMap<string, FolderSourceItem> ();
        saved_state = new AccountSavedState (account);
        saved_state.bind_with_expandable_item (this);

        offlinestore = (Camel.OfflineStore) account.service;
        name = offlinestore.display_name;
        offlinestore.folder_created.connect (folder_created);
        offlinestore.folder_deleted.connect (folder_deleted);
        offlinestore.folder_info_stale.connect (reload_folders);
        offlinestore.folder_renamed.connect (folder_renamed);
    }

    ~AccountSourceItem () {
        connect_cancellable.cancel ();
    }

    public async void load () {
        try {
            var folderinfo = yield offlinestore.get_folder_info (null, Camel.StoreGetFolderInfoFlags.RECURSIVE, GLib.Priority.DEFAULT, connect_cancellable);
            if (folderinfo != null) {
                show_info (folderinfo, this);
            }
        } catch (Error e) {
            critical (e.message);
        }
    }

    private void folder_renamed (string old_name, Camel.FolderInfo folder_info) {
        FolderSourceItem item;
        folder_items.unset (old_name, out item);
        item.update_infos (folder_info);
        folder_items[item.full_name] = item;
    }

    private void folder_deleted (Camel.FolderInfo folder_info) {
        Mail.FolderSourceItem? item = folder_items[folder_info.full_name];
        if (item != null) {
            item.parent.remove (item);
            folder_items.unset (folder_info.full_name);
        }
    }

    private void folder_created (Camel.FolderInfo folder_info) {
        if (folder_info.parent == null) {
            show_info (folder_info, this);
        } else {
            unowned Camel.FolderInfo parent_info = (Camel.FolderInfo) folder_info.parent;
            var parent_item = folder_items[parent_info.full_name];
            if (parent_item == null) {
                // Create the parent, then retry to create the children.
                folder_created (parent_info);
                folder_created (folder_info);
            } else {
                show_info (folder_info, parent_item);
            }
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
            folder_item.start_edit.connect (() => start_edit (folder_item));

            if (folderinfo.child != null) {
                show_info ((Camel.FolderInfo?) folderinfo.child, folder_item);
            }

            if (folder_item.is_special_folder) {
                add (folder_item);
            } else {
                item.add (folder_item);
            }

            folderinfo = (Camel.FolderInfo?) folderinfo.next;
        }
    }

    public int compare (Mail.SourceList.Item a, Mail.SourceList.Item b) {
        if (a is Mail.FolderSourceItem && b is Mail.FolderSourceItem) {
            var folder_a = (Mail.FolderSourceItem) a;
            var folder_b = (Mail.FolderSourceItem) b;

            return folder_a.pos - folder_b.pos;
        }

        return 0;
    }

    public bool allow_dnd_sorting () {
        return false;
    }

    public override Gtk.Menu? get_context_menu () {
        var menu = new Gtk.Menu ();

        var alias_item = new Gtk.MenuItem.with_label (_("Edit Aliases…"));
        alias_item.activate.connect (() => {
            new AliasDialog (account.service.uid) {
                transient_for = ((Gtk.Application) GLib.Application.get_default ()).active_window
            }.present ();
        });
        menu.add (alias_item);

        menu.show_all ();

        return menu;
    }
}
