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

public class Mail.ConversationListBox : Gtk.ListBox {
    public signal void conversation_selected (Camel.FolderThreadNode? node);
    public signal void conversation_focused (Camel.FolderThreadNode? node);

    public Backend.Account current_account { get; private set; }
    public Camel.Folder folder { get; private set; }

    private GLib.Cancellable? cancellable = null;
    private Camel.FolderThread thread;
    private string current_folder;
    private Gee.HashMap<string, ConversationListItem> conversations;

    construct {
        activate_on_single_click = true;
        conversations = new Gee.HashMap<string, ConversationListItem> ();
        set_header_func (thread_header_function);
        set_sort_func (thread_sort_function);
        row_activated.connect ((row) => {
            if (row == null) {
                conversation_focused (null);
            } else {
                conversation_focused (((ConversationListItem) row).node);
            }
        });
        row_selected.connect ((row) => {
            if (row == null) {
                conversation_selected (null);
            } else {
                conversation_selected (((ConversationListItem) row).node);
            }
        });
    }

    public async void load_folder (Backend.Account account, string next_folder) {
        current_folder = next_folder;
        current_account = account;
        if (cancellable != null) {
            cancellable.cancel ();
        }

        conversation_focused (null);
        conversation_selected (null);

        lock (conversations) {
            conversations.clear ();
            get_children ().foreach ((child) => {
                child.destroy ();
            });

            cancellable = new GLib.Cancellable ();
            try {
                folder = yield ((Camel.Store) current_account.service).get_folder (current_folder, 0, GLib.Priority.DEFAULT, cancellable);
                folder.changed.connect ((change_info) => folder_changed (change_info, cancellable));
                thread = new Camel.FolderThread (folder, folder.get_uids (), false);
                unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) thread.tree;
                while (child != null) {
                    if (cancellable.is_cancelled ()) {
                        break;
                    }

                    add_conversation_item (child);
                    child = (Camel.FolderThreadNode?) child.next;
                }

                yield folder.refresh_info (GLib.Priority.DEFAULT, cancellable);
            } catch (Error e) {
                critical (e.message);
            }
        }
    }

    private void folder_changed (Camel.FolderChangeInfo change_info, GLib.Cancellable cancellable) {
        if (cancellable.is_cancelled ()) {
            return;
        }

        lock (conversations) {
            thread.apply (folder.get_uids ());
            change_info.get_removed_uids ().foreach ((uid) => {
                var item = conversations[uid];
                if (item != null) {
                    conversations.unset (uid);
                    item.destroy ();
                }
            });

            unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) thread.tree;
            while (child != null) {
                if (cancellable.is_cancelled ()) {
                    return;
                }

                var item = conversations[child.message.uid];
                if (item == null) {
                    add_conversation_item (child);
                } else {
                    item.update_node (child);
                }

                child = (Camel.FolderThreadNode?) child.next;
            }
        }
    }

    private void add_conversation_item (Camel.FolderThreadNode child) {
        var item = new ConversationListItem (child);
        conversations[child.message.uid] = item;
        add (item);
    }

    private static int thread_sort_function (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        var item1 = (ConversationListItem) row1;
        var item2 = (ConversationListItem) row2;
        return (int)(item2.timestamp - item1.timestamp);
    }

    private static void thread_header_function (Gtk.ListBoxRow row1, Gtk.ListBoxRow? row2) {
        var item1 = (ConversationListItem) row1;
        var item2 = (ConversationListItem) row2;

        int64 item2_timestamp;
        if (item2 != null) {
            item2_timestamp = item2.timestamp;
        } else {
            item2_timestamp = 0;
        }

        if (item2_timestamp - item1.timestamp < 0) {
            var loading_label = new Gtk.Label (_("Updating…"));
            loading_label.halign = Gtk.Align.START;
            loading_label.valign = Gtk.Align.CENTER;
            loading_label.hexpand = loading_label.vexpand = true;

            var spinner = new Gtk.Spinner ();
            spinner.active = true;
            spinner.halign = Gtk.Align.END;
            spinner.valign = Gtk.Align.CENTER;
            spinner.hexpand = spinner.vexpand = true;

            var pull_to_refresh = new Gtk.Grid ();
            pull_to_refresh.column_spacing = 6;
            pull_to_refresh.height_request = 64;
            pull_to_refresh.get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);
            pull_to_refresh.add (spinner);
            pull_to_refresh.add (loading_label);
            pull_to_refresh.show_all ();

            row1.set_header (pull_to_refresh);
        } else {
            row1.set_header (null); 
        }
    }
}
