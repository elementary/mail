/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017-2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Mail.FolderPopover : Gtk.Popover {
    private Gtk.SearchEntry search_entry;
    private Gtk.ListBox list_box;

    construct {
        search_entry = new Gtk.SearchEntry () {
            margin_top = 12,
            margin_bottom = 9,
            margin_start = 12,
            margin_end = 12
        };

        list_box = new Gtk.ListBox () {
            activate_on_single_click = true
        };
        list_box.set_sort_func (sort_func);
        list_box.set_filter_func (filter_func);

        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            child = list_box,
            hexpand = true,
            vexpand = true,
            margin_bottom = 3,
            max_content_height = 350,
            propagate_natural_height = true,
            hscrollbar_policy = NEVER
        };

        var box = new Gtk.Box (VERTICAL, 0);
        box.add (search_entry);
        box.add (scrolled_window);
        box.show_all ();

        width_request = 250;
        child = box;

        search_entry.search_changed.connect (() => list_box.invalidate_filter ());

        list_box.row_activated.connect ((row) => {
            if (row is FolderRow) {
                var folder_row = (FolderRow)row;

                popdown ();
                ((MainWindow)get_toplevel ()).activate_action (MainWindow.ACTION_MOVE, row.folder_info.full_name);
            }
        });
    }

    public void set_store (Camel.Store store) {
        foreach (var child in list_box.get_children ()) {
            child.destroy ();
        }

        store.get_folder_info.begin (null, Camel.StoreGetFolderInfoFlags.RECURSIVE, GLib.Priority.DEFAULT, null, (obj, res) => {
            try {
                var folder_info = store.get_folder_info.end (res);
                update (folder_info, 0, store);
            } catch (Error e) {
                critical (e.message);
            }
        });
    }

    private void update (Camel.FolderInfo top, int depth, Camel.Store store) {
        var folder_info = top;
        while (folder_info != null) {
            list_box.add (new FolderRow (depth, folder_info, store));

            if (folder_info.child != null) {
                update (folder_info.child, depth + 1, store);
            }
            folder_info = folder_info.next;
        }
    }

    private int sort_func (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        if (row1 is FolderRow && row2 is FolderRow) {
            var folder_row1 = (FolderRow) row1;
            var folder_row2 = (FolderRow) row2;

            return folder_row1.pos - folder_row2.pos;
        }

        return 0;
    }

    private bool filter_func (Gtk.ListBoxRow row) {
        if (row is FolderRow) {
            var folder_row = (FolderRow)row;
            return search_entry.text.down ().strip () in folder_row.folder_info.display_name.down ();
        }

        return true;
    }
}
