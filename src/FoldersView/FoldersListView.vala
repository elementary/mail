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
    public signal void folder_selected (Backend.Account account, string folder_name);

    private Granite.Widgets.SourceList source_list;

    public FoldersListView () {
        
    }

    construct {
        width_request = 100;
        source_list = new Granite.Widgets.SourceList ();
        add (source_list);
        var session = Mail.Backend.Session.get_default ();
        foreach (var account in session.get_accounts ()) {
            var account_item = new Mail.AccountSourceItem (account);
            source_list.root.add (account_item);
        }

        session.account_added.connect ((account) => {
            var account_item = new Mail.AccountSourceItem (account);
            source_list.root.add (account_item);
        });

        source_list.item_selected.connect ((item) => {
            if (item == null || !(item is FolderSourceItem)) {
                return;
            }

            var folder_item = item as FolderSourceItem;
            folder_selected (folder_item.get_account (), folder_item.full_name);
        });
    }
}
