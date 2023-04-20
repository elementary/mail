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

public class Mail.AccountItemModel : ItemModel {
    public Mail.Backend.Account account { get; construct; }

    private GLib.Cancellable connect_cancellable;
    private unowned Camel.OfflineStore offlinestore;

    public AccountItemModel (Mail.Backend.Account account) {
        Object (account: account);
    }

    construct {
        offlinestore = (Camel.OfflineStore) account.service;

        icon_name = "avatar-default";
        name = offlinestore.display_name;
        account_uid = offlinestore.uid;
        folder_list = new ListStore (typeof (FolderItemModel));

        connect_cancellable = new GLib.Cancellable ();

        offlinestore.folder_created.connect (load);
        offlinestore.folder_deleted.connect (load);
        offlinestore.folder_info_stale.connect (load);
        offlinestore.folder_renamed.connect (load);

        unowned GLib.NetworkMonitor network_monitor = GLib.NetworkMonitor.get_default ();
        network_monitor.network_changed.connect (() =>{
            connect_to_account.begin ();
        });
        load.begin ();
    }

    ~AccountItemModel () {
        connect_cancellable.cancel ();
    }

    public async void load () {
        try {
            var folderinfo = yield offlinestore.get_folder_info (null, Camel.StoreGetFolderInfoFlags.RECURSIVE, GLib.Priority.DEFAULT, connect_cancellable);
            if (folderinfo != null) {
                show_info (folderinfo);
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

    private void show_info (Camel.FolderInfo? _folderinfo) {
        folder_list.remove_all ();

        var folderinfo = _folderinfo;
        while (folderinfo != null) {
            var folder_item = new FolderItemModel (folderinfo, account);
            folder_list.append (folder_item);
            folderinfo = (Camel.FolderInfo?) folderinfo.next;
        }
    }
}
