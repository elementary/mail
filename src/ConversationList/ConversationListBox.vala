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

    private const int MARK_READ_TIMEOUT_SECONDS = 5;

    public Gee.Map<Backend.Account, string?> folder_full_name_per_account { get; private set; }
    public Gee.HashMap<string, Camel.Folder> folders { get; private set; }

    private GLib.Cancellable? cancellable = null;
    private Gee.HashMap<string, Camel.FolderThread> threads;
    private string? current_search_query = null;
    private Gee.HashMap<string, ConversationItemModel> conversations;
    private ConversationListStore list_store;
    private MoveHandler move_handler;

    private uint mark_read_timeout_id = 0;

    construct {
        activate_on_single_click = true;
        conversations = new Gee.HashMap<string, ConversationItemModel> ();
        folders = new Gee.HashMap<string, Camel.Folder> ();
        threads = new Gee.HashMap<string, Camel.FolderThread> ();
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
        move_handler = new MoveHandler ();

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
            if (mark_read_timeout_id != 0) {
                GLib.Source.remove (mark_read_timeout_id);
                mark_read_timeout_id = 0;
            }

            if (row == null) {
                conversation_focused (null);
            } else {
                conversation_focused (((ConversationItemModel) row).node);

                if (((ConversationItemModel) row).unread) {
                    mark_read_timeout_id = GLib.Timeout.add_seconds (MARK_READ_TIMEOUT_SECONDS, () => {
                        set_thread_seen (((ConversationItemModel) row).node);

                        mark_read_timeout_id = 0;
                        return false;
                    });
                }
            }
        });

        row_selected.connect ((row) => {
            if (row == null) {
                conversation_selected (null);
            } else {
                // We call get_action_group() on the parent window, instead of on `this` directly, due to a
                // bug with Gtk.Widget.get_action_group(). See https://gitlab.gnome.org/GNOME/gtk/issues/1396
                var window = (Gtk.ApplicationWindow) get_toplevel ();
                weak GLib.ActionMap win_action_map = (GLib.ActionMap) window.get_action_group (MainWindow.ACTION_GROUP_PREFIX);
                ((SimpleAction) win_action_map.lookup_action (MainWindow.ACTION_MARK_READ)).set_enabled (((ConversationItemModel) row).unread);
                ((SimpleAction) win_action_map.lookup_action (MainWindow.ACTION_MARK_UNREAD)).set_enabled (!((ConversationItemModel) row).unread);
                ((SimpleAction) win_action_map.lookup_action (MainWindow.ACTION_MARK_STAR)).set_enabled (!((ConversationItemModel) row).flagged);
                ((SimpleAction) win_action_map.lookup_action (MainWindow.ACTION_MARK_UNSTAR)).set_enabled (((ConversationItemModel) row).flagged);
                conversation_selected (((ConversationItemModel) row).node);
            }
        });
    }

    private static void set_thread_seen (Camel.FolderThreadNode? node) {
        if (!(Camel.MessageFlags.SEEN in (int)node.message.flags)) {
            node.message.set_flags (Camel.MessageFlags.SEEN, ~0);
        }

        for (unowned Camel.FolderThreadNode? child = node.child; child != null; child = child.next) {
            set_thread_seen (child);
        }
    }

    public async void load_folder (Gee.Map<Backend.Account, string?> folder_full_name_per_account) {
        lock (this.folder_full_name_per_account) {
            this.folder_full_name_per_account = folder_full_name_per_account;
        }

        if (cancellable != null) {
            cancellable.cancel ();
        }

        conversation_focused (null);
        conversation_selected (null);

        uint previous_items = list_store.get_n_items ();
        lock (conversations) {
            lock (folders) {
                lock (threads) {
                    conversations.clear ();
                    folders.clear ();
                    threads.clear ();

                    list_store.remove_all ();
                    list_store.items_changed (0, previous_items, 0);

                    cancellable = new GLib.Cancellable ();

                    lock (this.folder_full_name_per_account) {
                        foreach (var folder_full_name_entry in this.folder_full_name_per_account) {
                            var current_account = folder_full_name_entry.key;
                            var current_full_name = folder_full_name_entry.value;

                            if (current_full_name == null) {
                                continue;
                            }

                            try {
                                var folder = yield ((Camel.Store) current_account.service).get_folder (current_full_name, 0, GLib.Priority.DEFAULT, cancellable);
                                folders[current_account.service.uid] = folder;
                                folder.changed.connect ((change_info) => folder_changed (change_info, current_account.service.uid, cancellable));

                                var search_result_uids = get_search_result_uids (current_account.service.uid);
                                if (search_result_uids != null) {
                                    var thread = new Camel.FolderThread (folder, search_result_uids, false);
                                    threads[current_account.service.uid] = thread;

                                    unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) thread.tree;
                                    while (child != null) {
                                        if (cancellable.is_cancelled ()) {
                                            break;
                                        }

                                        add_conversation_item (child, current_account.service.uid);
                                        child = (Camel.FolderThreadNode?) child.next;
                                    }

                                    yield folder.refresh_info (GLib.Priority.DEFAULT, cancellable);
                                }

                            } catch (Error e) {
                                // We can cancel the operation
                                if (!(e is GLib.IOError.CANCELLED)) {
                                    critical (e.message);
                                }
                            }
                        }
                    }
                }
            }
        }

        list_store.items_changed (0, 0, list_store.get_n_items ());
    }

    private void folder_changed (Camel.FolderChangeInfo change_info, string service_uid, GLib.Cancellable cancellable) {
        if (cancellable.is_cancelled ()) {
            return;
        }

        lock (conversations) {
            lock (threads) {
                var search_result_uids = get_search_result_uids (service_uid);
                if (search_result_uids == null) {
                    return;
                }
                threads[service_uid].apply (search_result_uids);

                var removed = 0;
                change_info.get_removed_uids ().foreach ((uid) => {
                    var item = conversations[uid];
                    if (item != null) {
                        conversations.unset (uid);
                        list_store.remove (item);
                        removed++;
                    }
                });

                unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) threads[service_uid].tree;
                while (child != null) {
                    if (cancellable.is_cancelled ()) {
                        return;
                    }

                    var item = conversations[child.message.uid];
                    if (item == null) {
                        add_conversation_item (child, service_uid);
                    } else {
                        if (item.update_node (child)) {
                            conversations.unset (child.message.uid);
                            list_store.remove (item);
                            removed++;
                            add_conversation_item (child, service_uid);
                        };

                    }

                    child = (Camel.FolderThreadNode?) child.next;
                }

                list_store.items_changed (0, removed, list_store.get_n_items ());
            }
        }
    }

    private GenericArray<string>? get_search_result_uids (string service_uid) {
        lock (folders) {
            if (folders[service_uid] == null) {
                return null;
            }

            if (current_search_query == null) {
                return folders[service_uid].get_uids ();
            }

            var sb = new StringBuilder ();
            Camel.SExp.encode_string (sb, current_search_query);
            var encoded_query = sb.str;

            string search_query = """(match-all (or (header-contains "From" %s)(header-contains "Subject" %s)(body-contains %s)))"""
                .printf (encoded_query, encoded_query, encoded_query);

            try {
                return folders[service_uid].search_by_expression (search_query, cancellable);
            } catch (Error e) {
                if (!(e is GLib.IOError.CANCELLED)) {
                    warning ("Error while searching: %s", e.message);
                }

                return folders[service_uid].get_uids ();
            }
        }
    }

    public void search (string? query) {
        current_search_query = query;
        load_folder.begin (folder_full_name_per_account);
    }

    private void add_conversation_item (Camel.FolderThreadNode child, string service_uid) {
        var item = new ConversationItemModel (child, service_uid);
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

    public async int archive_selected_messages () {
        var archive_threads = new Gee.HashMap<string, Gee.ArrayList<Camel.FolderThreadNode?>> ();
        var selected_rows = get_selected_rows ();
        foreach (unowned var selected_row in selected_rows) {
            var selected_item_model = (ConversationItemModel) selected_row;

            if (archive_threads[selected_item_model.service_uid] == null) {
                archive_threads[selected_item_model.service_uid] = new Gee.ArrayList<Camel.FolderThreadNode?> ();
            }
            archive_threads[selected_item_model.service_uid].add (selected_item_model.node);
        }

        var archived = 0;
        foreach (var service_uid in archive_threads.keys) {
            archived += yield move_handler.archive_threads (folders[service_uid], archive_threads[service_uid]);
        }

        if (archived > 0) {
            foreach (var service_uid in archive_threads.keys) {
                var threads = archive_threads[service_uid];

                foreach (var thread in threads) {
                    var uid = thread.message.uid;
                    var item = conversations[uid];
                    if (item != null) {
                        conversations.unset (uid);
                        list_store.remove (item);
                    }
                }
            }
        }

        list_store.items_changed (0, archived, list_store.get_n_items ());
        return archived;
    }

    public int trash_selected_messages () {
        var trash_threads = new Gee.HashMap<string, Gee.ArrayList<Camel.FolderThreadNode?>> ();

        var selected_rows = get_selected_rows ();
        foreach (unowned var selected_row in selected_rows) {
            var selected_item_model = (ConversationItemModel) selected_row;

            if (trash_threads[selected_item_model.service_uid] == null) {
                trash_threads[selected_item_model.service_uid] = new Gee.ArrayList<Camel.FolderThreadNode?> ();
            }
            trash_threads[selected_item_model.service_uid].add (selected_item_model.node);
        }

        var deleted = 0;
        foreach (var service_uid in trash_threads.keys) {
            deleted += move_handler.delete_threads (folders[service_uid], trash_threads[service_uid]);
        }
        list_store.items_changed (0, 0, list_store.get_n_items ());
        return deleted;
    }

    public void undo_move () {
        move_handler.undo_last_move.begin ((obj, res) => {
            move_handler.undo_last_move.end (res);
            list_store.items_changed (0, 0, list_store.get_n_items ());
        });
    }

    public void undo_expired () {
        move_handler.expire_undo ();
    }
}
