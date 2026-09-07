/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017-2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Mail.FolderPopover : Gtk.Popover {
    private Gtk.SearchEntry search_entry;
    private ListStore folder_list;

    construct {
        search_entry = new Gtk.SearchEntry () {
            margin_top = 12,
            margin_bottom = 9,
            margin_start = 12,
            margin_end = 12
        };

        var placeholder = new Granite.Placeholder (_("No mailboxes found")) {
            description = _("Try changing search terms"),
            icon = new ThemedIcon ("edit-find-symbolic")
        };

        folder_list = new ListStore (typeof (FolderRow));

        var list_box = new Gtk.ListBox () {
            activate_on_single_click = true
        };
        list_box.bind_model (folder_list, (obj) => (FolderRow) obj);
        list_box.set_filter_func (filter_func);
        list_box.set_placeholder (placeholder);

        var scrolled_window = new Gtk.ScrolledWindow () {
            child = list_box,
            hexpand = true,
            vexpand = true,
            margin_bottom = 3,
            max_content_height = 350,
            propagate_natural_height = true,
            hscrollbar_policy = NEVER
        };

        var box = new Gtk.Box (VERTICAL, 0);
        box.append (search_entry);
        box.append (scrolled_window);

        width_request = 250;
        child = box;

        search_entry.search_changed.connect (list_box.invalidate_filter);

        list_box.row_activated.connect ((row) => {
            if (row is FolderRow) {
                var folder_row = (FolderRow)row;

                popdown ();
                ((MainWindow)get_root ()).activate_action (MainWindow.ACTION_MOVE, row.folder_info.full_name);
            }
        });
    }

    public void set_store (Camel.Store store) {
        folder_list.remove_all ();

        store.get_folder_info.begin (null, Camel.StoreGetFolderInfoFlags.RECURSIVE, GLib.Priority.DEFAULT, null, (obj, res) => {
            try {
                var folder_info = store.get_folder_info.end (res);
                update (folder_info, store);
            } catch (Error e) {
                critical (e.message);
            }
        });
    }

    private void update (Camel.FolderInfo top, Camel.Store store) {
        var folder_info = top;
        while (folder_info != null) {
            folder_list.insert_sorted (new FolderRow (folder_info, store), sort_func);

            if (folder_info.child != null) {
                update (folder_info.child, store);
            }

            folder_info = folder_info.next;
        }
    }

    private int sort_func (Object row1, Object row2) {
        var folder_row1 = (FolderRow) row1;
        var folder_row2 = (FolderRow) row2;

        return folder_row1.pos - folder_row2.pos;
    }

    private bool filter_func (Gtk.ListBoxRow row) {
        if (row is FolderRow) {
            var folder_row = (FolderRow)row;
            return search_entry.text.down ().strip () in folder_row.folder_info.display_name.down ();
        }

        return true;
    }
}
