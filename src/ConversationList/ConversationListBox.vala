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

public class Mail.ConversationListBox : VirtualizingListBox {
    public signal void conversation_selected (Camel.FolderThreadNode? node);
    public signal void conversation_focused (Camel.FolderThreadNode? node);

    public Backend.Account current_account { get; private set; }
    public Camel.Folder folder { get; private set; }

    private GLib.Cancellable? cancellable = null;
    private Camel.FolderThread thread;
    private string current_folder;
    private Gee.HashMap<string, ConversationItemModel> conversations;
    private ConversationListStore list_store;
    private TrashHandler trash_handler;

    construct {
        activate_on_single_click = true;
        conversations = new Gee.HashMap<string, ConversationItemModel> ();
        list_store = new ConversationListStore ();
        list_store.set_sort_func (thread_sort_function);
        list_store.set_filter_func ((obj) => {
            if (obj is ConversationItemModel) {
                return !((ConversationItemModel)obj).deleted;
            } else {
                return false;
            }
        });

        model = list_store;
        trash_handler = new TrashHandler ();

        factory_func = (item, old_widget) => {
            ConversationListItem? row = null;
            if (old_widget != null) {
                row = old_widget as ConversationListItem;
            } else {
                row = new ConversationListItem ();
            }

            row.assign ((ConversationItemModel)item);
            row.show_all ();
            return row;
        };

        row_activated.connect ((row) => {
            if (row == null) {
                conversation_focused (null);
            } else {
                conversation_focused (((ConversationItemModel) row).node);
            }
        });

        row_selected.connect ((row) => {
            if (row == null) {
                conversation_selected (null);
            } else {
                weak GLib.ActionMap win_action_map = (GLib.ActionMap) get_action_group (MainWindow.ACTION_GROUP_PREFIX);
                ((SimpleAction) win_action_map.lookup_action (MainWindow.ACTION_MARK_READ)).set_enabled (((ConversationItemModel) row).unread);
                ((SimpleAction) win_action_map.lookup_action (MainWindow.ACTION_MARK_UNREAD)).set_enabled (!((ConversationItemModel) row).unread);
                ((SimpleAction) win_action_map.lookup_action (MainWindow.ACTION_MARK_STAR)).set_enabled (!((ConversationItemModel) row).flagged);
                ((SimpleAction) win_action_map.lookup_action (MainWindow.ACTION_MARK_UNSTAR)).set_enabled (((ConversationItemModel) row).flagged);
                conversation_selected (((ConversationItemModel) row).node);
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

        uint previous_items = list_store.get_n_items ();
        lock (conversations) {
            conversations.clear ();
            list_store.remove_all ();
            list_store.items_changed (0, previous_items, 0);

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

        list_store.items_changed (0, 0, list_store.get_n_items ());
    }

    private void folder_changed (Camel.FolderChangeInfo change_info, GLib.Cancellable cancellable) {
        if (cancellable.is_cancelled ()) {
            return;
        }

        lock (conversations) {
            thread.apply (folder.get_uids ());
            var removed = 0;
            change_info.get_removed_uids ().foreach ((uid) => {
                var item = conversations[uid];
                if (item != null) {
                    conversations.unset (uid);
                    list_store.remove (item);
                    removed++;
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

            list_store.items_changed (0, removed, list_store.get_n_items ());
        }
    }

    private void add_conversation_item (Camel.FolderThreadNode child) {
        var item = new ConversationItemModel (child);
        conversations[child.message.uid] = item;
        list_store.add (item);
    }

    private static int thread_sort_function (ConversationItemModel item1, ConversationItemModel item2) {
        return (int)(item2.timestamp - item1.timestamp);
    }

    public void mark_read_selected_messages () {
        var selected_rows = get_selected_rows ();
        foreach (var row in selected_rows) {
            (((ConversationItemModel)row).node).message.set_flags (Camel.MessageFlags.SEEN, ~0);
        }
    }

    public void mark_star_selected_messages () {
        var selected_rows = get_selected_rows ();
        foreach (var row in selected_rows) {
            (((ConversationItemModel)row).node).message.set_flags (Camel.MessageFlags.FLAGGED, ~0);
        }
    }

    public void mark_unread_selected_messages () {
        var selected_rows = get_selected_rows ();
        foreach (var row in selected_rows) {
            (((ConversationItemModel)row).node).message.set_flags (Camel.MessageFlags.SEEN, 0);
        }
    }

    public void mark_unstar_selected_messages () {
        var selected_rows = get_selected_rows ();
        foreach (var row in selected_rows) {
            (((ConversationItemModel)row).node).message.set_flags (Camel.MessageFlags.FLAGGED, 0);
        }
    }

    public int trash_selected_messages () {
        var threads = new Gee.ArrayList<Camel.FolderThreadNode?> ();
        var selected_rows = get_selected_rows ();
        foreach (var row in selected_rows) {
            threads.add (((ConversationItemModel)row).node);
        }

        var deleted = trash_handler.delete_threads (folder, threads);
        list_store.items_changed (0, 0, list_store.get_n_items ());
        return deleted;
    }

    public void undo_trash () {
        trash_handler.undo_last_delete ();
        list_store.items_changed (0, 0, list_store.get_n_items ());
    }

    public void undo_expired () {
        trash_handler.expire_undo ();
    }
}
