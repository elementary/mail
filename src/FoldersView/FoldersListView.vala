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

public class Mail.FoldersListView : Gtk.ScrolledWindow {
    public signal void folder_selected (Backend.Account account, string folder_name, int folder_type);

    private Granite.Widgets.SourceList source_list;
    private static GLib.Settings settings;

    private string selected_folder_uid;
    private string selected_folder_name;

    public FoldersListView () {
        
    }

    static construct {
        settings = new GLib.Settings ("io.elementary.mail");
    }

    construct {
        width_request = 100;

        settings.get ("selected-folder", "(ss)", out selected_folder_uid, out selected_folder_name);

        source_list = new Granite.Widgets.SourceList ();
        add (source_list);
        var session = Mail.Backend.Session.get_default ();
        session.get_accounts ().foreach ((account) => {
            add_account (account);
            return true;
        });

        session.account_added.connect (add_account);
        source_list.item_selected.connect ((item) => {
            if (item == null || !(item is FolderSourceItem)) {
                return;
            }

            var folder_item = item as FolderSourceItem;
            folder_selected (folder_item.get_account (), folder_item.full_name, folder_item.folder_type);

            settings.set ("selected-folder", "(ss)", folder_item.get_account ().service.uid, folder_item.full_name);
        });
    }

    private void add_account (Mail.Backend.Account account) {
        var account_item = new Mail.AccountSourceItem (account);
        source_list.root.add (account_item);

        if (account.service.uid == selected_folder_uid) {
            folder_selected (account, selected_folder_name, 0 /* FIXME: get flags */);
        }
    }
}
