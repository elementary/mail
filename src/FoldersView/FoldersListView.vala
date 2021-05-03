// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2021 elementary LLC. (https://elementary.io)
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
    public signal void folders_selected (Backend.Account[] accounts, string?[] folder_names);

    private Granite.Widgets.SourceList source_list;
    private static GLib.Settings settings;

    static construct {
        settings = new GLib.Settings ("io.elementary.mail");
    }

    construct {
        width_request = 100;

        source_list = new Granite.Widgets.SourceList ();
        add (source_list);
        var session = Mail.Backend.Session.get_default ();

        var session_source_item = new Mail.SessionSourceItem (session);
        source_list.root.add (session_source_item);

        session.get_accounts ().foreach ((account) => {
            add_account (account);
            return true;
        });

        session.account_added.connect (add_account);
        source_list.item_selected.connect ((item) => {
            if (item == null) {
                return;
            }

            if (item is FolderSourceItem) {
                unowned FolderSourceItem folder_item = (FolderSourceItem) item;
                folders_selected ({ folder_item.account }, { folder_item.full_name });

                settings.set ("selected-folder", "(ss)", folder_item.account.service.uid, folder_item.full_name);

            } else if (item is GroupedFolderSourceItem) {
                unowned GroupedFolderSourceItem grouped_folder_item = (GroupedFolderSourceItem) item;
                var folder_full_names = grouped_folder_item.get_folder_full_names ();

                folders_selected (grouped_folder_item.get_accounts (), folder_full_names);
                settings.set ("selected-folder", "(ss)", "GROUPED", folder_full_names[0]);
            }
        });
    }

    private void add_account (Mail.Backend.Account account) {
        var account_item = new Mail.AccountSourceItem (account);
        source_list.root.add (account_item);
        account_item.load.begin ((obj, res) => {
            account_item.load.end (res);
            string selected_folder_uid, selected_folder_name;
            settings.get ("selected-folder", "(ss)", out selected_folder_uid, out selected_folder_name);
            if (account.service.uid == selected_folder_uid) {
                select_saved_folder (account_item, selected_folder_name);
            }
        });
    }

    private bool select_saved_folder (Granite.Widgets.SourceList.ExpandableItem item, string selected_folder_name) {
        foreach (var child in item.children) {
            if (child is FolderSourceItem) {
                if (select_saved_folder ((Granite.Widgets.SourceList.ExpandableItem) child, selected_folder_name)) {
                    return true;
                }

                unowned FolderSourceItem folder_item = (FolderSourceItem) child;
                if (folder_item.full_name == selected_folder_name) {
                    source_list.selected = child;
                    folders_selected ({ folder_item.account }, { selected_folder_name });
                    return true;
                }
            }
        }

        return false;
    }
}
