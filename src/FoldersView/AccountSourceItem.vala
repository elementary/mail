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

public class Mail.AccountSourceItem : Granite.Widgets.SourceList.ExpandableItem {
    public Mail.Backend.Account account { get; construct; }

    public AccountSourceItem (Mail.Backend.Account account) {
        Object (account: account);
    }

    construct {
        var offlinestore = (Camel.OfflineStore) account.service;
        name = offlinestore.display_name;
        offlinestore.folder_created.connect ((folder_info) => {critical ("");});
        offlinestore.folder_deleted.connect ((folder_info) => {critical ("");});
        offlinestore.folder_info_stale.connect (() => {critical ("");});
        offlinestore.folder_renamed.connect ((old_name, folder_info) => {critical ("");});
        try {
            offlinestore.set_online_sync (true);
            offlinestore.connect_sync ();
            var folderinfo = offlinestore.get_folder_info_sync (null, Camel.StoreGetFolderInfoFlags.RECURSIVE);
            if (folderinfo != null) {
                show_info (folderinfo, this);
            }
        } catch (Error e) {
            critical (e.message);
        }
    }


    private static void show_info (Camel.FolderInfo? _folderinfo, Granite.Widgets.SourceList.ExpandableItem item) {
        var folderinfo = _folderinfo;
        while (folderinfo != null) {
            Granite.Widgets.SourceList.Item sub_item;
            if (folderinfo.child != null) {
                sub_item = new Granite.Widgets.SourceList.ExpandableItem (folderinfo.display_name);
                show_info ((Camel.FolderInfo?) folderinfo.child, (Granite.Widgets.SourceList.ExpandableItem) sub_item);
            } else {
                sub_item = new FolderSourceItem (folderinfo);
            }

            item.add (sub_item);
            folderinfo = (Camel.FolderInfo?) folderinfo.next;
        }
    }
}
