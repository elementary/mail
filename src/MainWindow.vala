// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.MainWindow : Gtk.Window {
    FoldersListView folders_list_view;
    ConversationListBox conversation_list_box;

    public MainWindow () {
        Object (
            height_request: 640,
            width_request: 910
        );
    }

    construct {
        var headerbar = new HeaderBar ();
        set_titlebar (headerbar);

        folders_list_view = new FoldersListView ();
        conversation_list_box = new ConversationListBox ();

        var conversation_list_scrolled = new Gtk.ScrolledWindow (null, null);
        conversation_list_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        conversation_list_scrolled.add (conversation_list_box);

        var paned_start = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned_start.add1 (folders_list_view);
        paned_start.add2 (conversation_list_scrolled);

        var paned_end = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned_end.add1 (paned_start);

        add (paned_end);
        var settings = new GLib.Settings ("io.elementary.mail");
        settings.bind ("paned-start-position", paned_start, "position", SettingsBindFlags.DEFAULT);

        destroy.connect (() => destroy ());

        folders_list_view.folder_selected.connect ((account, folder_name) => {
            conversation_list_box.set_folder.begin (account, folder_name);
        });

        Backend.Session.get_default ().start.begin ();
    }
}
