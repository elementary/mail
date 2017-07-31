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
    public signal void conversation_selected (Camel.FolderThreadNode node);
    public signal void conversation_focused (Camel.FolderThreadNode node);

    private string current_folder;
    private Backend.Account current_account;
    private GLib.Cancellable? cancellable = null;
    private Camel.Folder folder;
    private Camel.FolderThread thread;
    private Gee.HashMap<string, ConversationListItem> conversations;

    construct {
        selection_mode = Gtk.SelectionMode.MULTIPLE;
        activate_on_single_click = true;
        conversations = new Gee.HashMap<string, ConversationListItem> ();
        set_sort_func (thread_sort_function);
        row_activated.connect ((row) => {
            conversation_focused (((ConversationListItem) row).node);
        });
        row_selected.connect ((row) => {
            conversation_selected (((ConversationListItem) row).node);
        });
    }

    public async void set_folder (Backend.Account account, string next_folder) {
        current_folder = next_folder;
        current_account = account;
        if (cancellable != null) {
            cancellable.cancel ();
        }

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
        if (cancellable.is_cancelled ())
            return;

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
                if (cancellable.is_cancelled ())
                    return;

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
        return (int)(item2.node.message.date_received - item1.node.message.date_received);
    }
}
