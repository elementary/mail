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

public class Mail.ConversationListBox : Gtk.Box {
    public signal void conversation_selected (Camel.FolderThreadNode? node);
    public signal void conversation_focused (Camel.FolderThreadNode? node);

    private const int MARK_READ_TIMEOUT_SECONDS = 5;

    public Gee.Map<Backend.Account, string?> folder_full_name_per_account { get; private set; }
    public Gee.HashMap<string, Camel.Folder> folders { get; private set; }
    public Gee.HashMap<string, Camel.FolderInfoFlags> folder_info_flags { get; private set; }

    private GLib.Cancellable? cancellable = null;
    private Gee.HashMap<string, Camel.FolderThread> threads;
    private Gee.HashMap<string, ConversationItemModel> conversations;

    private string? current_search_query = null;
    private bool current_search_hide_read = false;
    private bool current_search_hide_unstarred = false;
    private Gtk.EveryFilter every_filter;
    private ListStore list_store;
    private Gtk.SingleSelection selection_model;
    private Gtk.ListView list_view;
    private Gtk.ScrolledWindow scrolled_window;
    private MoveHandler move_handler;

    private uint mark_read_timeout_id = 0;

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        spacing = 0;

        var factory = new Gtk.SignalListItemFactory ();
        factory.setup.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;

            list_item.set_child (new ConversationListItem ());
        });
        factory.bind.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;
            var conversation_list_item = (ConversationListItem) list_item.child;
            conversation_list_item.handler_id = conversation_list_item.secondary_click.connect ((x, y) => {
                if (!selection_model.is_selected (list_item.get_position ())) {
                    selection_model.select_item (list_item.get_position (), false);
                }
                create_context_menu (x, y, conversation_list_item);
            });
            ((ConversationListItem)list_item.child).assign((ConversationItemModel) list_item.get_item ());
        });
        factory.unbind.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;
            var conversation_list_item = (ConversationListItem) list_item.child;
            conversation_list_item.disconnect (conversation_list_item.handler_id);
        });

        list_store = new ListStore (typeof(ConversationItemModel));

        every_filter = new Gtk.EveryFilter ();
        var hide_unread_filter = new Gtk.CustomFilter (filter_unread_func);
        var hide_unstarred_filter = new Gtk.CustomFilter (filter_unstarred_func);
        var deleted_filter = new Gtk.CustomFilter (filter_deleted_func);
        //var search_filter = new Gtk.CustomFilter (search_func); @TODO: make search local?
        every_filter.append (hide_unread_filter);
        every_filter.append (hide_unstarred_filter);
        every_filter.append (deleted_filter);
        //every_filter.append (search_filter);
        var filter_model = new Gtk.FilterListModel (list_store, every_filter);

        selection_model = new Gtk.SingleSelection (filter_model) {
            autoselect = false
        };

        list_view = new Gtk.ListView (selection_model, factory);
        scrolled_window = new Gtk.ScrolledWindow () {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            width_request = 158,
            vexpand = true,
            hexpand = true,
            child = list_view
        };
        this.append (scrolled_window);

        conversations = new Gee.HashMap<string, ConversationItemModel> ();
        folders = new Gee.HashMap<string, Camel.Folder> ();
        folder_info_flags = new Gee.HashMap<string, Camel.FolderInfoFlags> ();
        threads = new Gee.HashMap<string, Camel.FolderThread> ();
        move_handler = new MoveHandler ();

        selection_model.selection_changed.connect ((position) => {
            if (mark_read_timeout_id != 0) {
                GLib.Source.remove (mark_read_timeout_id);
                mark_read_timeout_id = 0;
            }

            var selected_items = selection_model.get_selection ();
            uint current_item_position;
            Gtk.BitsetIter bitset_iter = Gtk.BitsetIter ();
            bitset_iter.init_first(selected_items, out current_item_position);
            assert(bitset_iter.is_valid());

            var conversation_item = (ConversationItemModel) selection_model.get_item (current_item_position);
            conversation_focused (conversation_item.node);

            if (conversation_item.unread) {
                mark_read_timeout_id = GLib.Timeout.add_seconds (MARK_READ_TIMEOUT_SECONDS, () => {
                    set_thread_flag (conversation_item.node, Camel.MessageFlags.SEEN);

                    mark_read_timeout_id = 0;
                    return false;
                });
            }
            // We call get_action_group() on the parent window, instead of on `this` directly, due to a
            // bug with Gtk.Widget.get_action_group(). See https://gitlab.gnome.org/GNOME/gtk/issues/1396
            var window = (Gtk.ApplicationWindow) get_root ();
            //@TODO: Is this really needed? If it is, a workaround has to be made to be able to mark read and then unread the same message without selecting another one between
            //((SimpleAction) window.lookup_action (MainWindow.ACTION_MARK_READ)).set_enabled (conversation_item.unread);
            //((SimpleAction) window.lookup_action (MainWindow.ACTION_MARK_UNREAD)).set_enabled (!conversation_item.unread);
            //((SimpleAction) window.lookup_action (MainWindow.ACTION_MARK_STAR)).set_enabled (!conversation_item.flagged);
            //((SimpleAction) window.lookup_action (MainWindow.ACTION_MARK_UNSTAR)).set_enabled (conversation_item.flagged);
            conversation_selected (conversation_item.node);
        });
    }

    private static void set_thread_flag (Camel.FolderThreadNode? node, Camel.MessageFlags flag) {
        if (node == null) {
            return;
        }

        if (!(flag in (int)node.message.flags)) {
            node.message.set_flags (flag, ~0);
        }

        for (unowned Camel.FolderThreadNode? child = node.child; child != null; child = child.next) {
            set_thread_flag (child, flag);
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

        lock (conversations) {
            lock (folders) {
                lock (threads) {
                    conversations.clear ();
                    folders.clear ();
                    threads.clear ();

                    list_store.remove_all ();

                    cancellable = new GLib.Cancellable ();

                    lock (this.folder_full_name_per_account) {
                        foreach (var folder_full_name_entry in this.folder_full_name_per_account) {
                            var current_account = folder_full_name_entry.key;
                            var current_full_name = folder_full_name_entry.value;

                            if (current_full_name == null) {
                                continue;
                            }

                            try {
                                var camel_store = (Camel.Store) current_account.service;

                                var folder = yield camel_store.get_folder (current_full_name, 0, GLib.Priority.DEFAULT, cancellable);
                                folders[current_account.service.uid] = folder;

                                var info_flags = Utils.get_full_folder_info_flags (current_account.service, yield camel_store.get_folder_info (folder.full_name, 0, GLib.Priority.DEFAULT));
                                folder_info_flags[current_account.service.uid] = info_flags;

                                folder.changed.connect ((change_info) => folder_changed (change_info, current_account.service.uid, cancellable));

                                var search_result_uids = get_search_result_uids (current_account.service.uid);
                                if (search_result_uids != null) {
                                    var thread = new Camel.FolderThread (folder, search_result_uids, false);
                                    threads[current_account.service.uid] = thread;

                                    weak Camel.FolderThreadNode? child = thread.tree;
                                    while (child != null) {
                                        if (cancellable.is_cancelled ()) {
                                            break;
                                        }

                                        add_conversation_item (folder_info_flags[current_account.service.uid], child, thread, current_account.service.uid);
                                        child = child.next;
                                    }
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
        list_store.sort (sort_func); //@TODO: scroll to top
    }

    public async void refresh_folder (GLib.Cancellable? cancellable = null) {
        lock (folders) {
            foreach (var folder in folders.values) {
                try {
                    yield folder.refresh_info (GLib.Priority.DEFAULT, cancellable);
                } catch (Error e) {
                    warning ("Error fetching messages for '%s' from '%s': %s",
                    folder.display_name,
                    folder.parent_store.display_name,
                    e.message);
                }
            }
        }
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
                threads[service_uid] = new Camel.FolderThread (folders[service_uid], search_result_uids, false);

                var removed = list_store.get_n_items ();

                change_info.get_removed_uids ().foreach ((uid) => {
                    var item = conversations[uid];
                    if (item != null) {
                        conversations.unset (uid);
                        uint item_position;
                        list_store.find (item, out item_position);
                        list_store.remove (item_position);
                    }
                });

                var added = list_store.get_n_items ();

                unowned Camel.FolderThreadNode? child = threads[service_uid].tree;
                while (child != null) {
                    if (cancellable.is_cancelled ()) {
                        return;
                    }

                    var item = conversations[child.message.uid];
                    if (item == null) {
                        add_conversation_item (folder_info_flags[service_uid], child, threads[service_uid], service_uid);
                        added++;
                    } else {
                        if (item.is_older_than (child)) {
                            conversations.unset (child.message.uid);
                            uint item_position;
                            list_store.find (item, out item_position);
                            list_store.remove (item_position);
                            removed++;
                            add_conversation_item (folder_info_flags[service_uid], child, threads[service_uid], service_uid);
                        };
                    }
                    child = child.next;
                }
                list_store.items_changed (0, removed, added);
            }
        }
    }

    private GenericArray<string>? get_search_result_uids (string service_uid) {
        //@TODO: make search local?
        lock (folders) {
            if (folders[service_uid] == null) {
                return null;
            }

            var has_current_search_query = current_search_query != null && current_search_query.strip () != "";
            if (!has_current_search_query) {
                return folders[service_uid].get_uids ();
            }

            string[] current_search_expressions = {};

            var sb = new StringBuilder ();
            Camel.SExp.encode_string (sb, current_search_query);
            var encoded_query = sb.str;

            current_search_expressions += """(or (header-contains "From" %s)(header-contains "Subject" %s)(body-contains %s))"""
            .printf (encoded_query, encoded_query, encoded_query);

            string search_query = "(match-all (and " + string.joinv ("", current_search_expressions) + "))";

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

    public async void search (string? query, bool hide_read = false, bool hide_unstarred = false) {
        current_search_query = query;
        current_search_hide_read = hide_read;
        current_search_hide_unstarred = hide_unstarred;
        yield load_folder (folder_full_name_per_account);
        every_filter.changed (DIFFERENT);
    }

    private void add_conversation_item (Camel.FolderInfoFlags folder_info_flags, Camel.FolderThreadNode child, Camel.FolderThread thread, string service_uid) {
        var item = new ConversationItemModel (folder_info_flags, child, thread, service_uid);
        conversations[child.message.uid] = item;
        list_store.append (item);
    }

    private bool filter_unread_func (Object item) {
        var conversation_item = (ConversationItemModel) item;
        if (current_search_hide_read) {
            return conversation_item.unread;
        } else {
            return true;
        }
    }

    private bool filter_unstarred_func (Object item) {
        var conversation_item = (ConversationItemModel) item;
        if (current_search_hide_unstarred) {
            return conversation_item.flagged;
        } else {
            return true;
        }
    }

    private static bool filter_deleted_func (Object item) {
        if (item is ConversationItemModel) {
            return !((ConversationItemModel)item).deleted;
        } else {
            return false;
        }
    }

    public int sort_func (Object a, Object b) {
        var item1 = (ConversationItemModel) a;
        var item2 = (ConversationItemModel) b;
        return (int)(item2.timestamp - item1.timestamp);
    }

    public void mark_read_selected_messages () {
        var selected_items = selection_model.get_selection ();
        uint current_item_position;
        Gtk.BitsetIter bitset_iter = Gtk.BitsetIter ();
        bitset_iter.init_first(selected_items, out current_item_position);
        do {
            ((ConversationItemModel)selection_model.get_item (current_item_position)).node.message.set_flags (Camel.MessageFlags.SEEN, ~0);
            bitset_iter.next (out current_item_position);
        } while (bitset_iter.is_valid());
    }

    public void mark_star_selected_messages () {
        var selected_items = selection_model.get_selection ();
        uint current_item_position;
        Gtk.BitsetIter bitset_iter = Gtk.BitsetIter ();
        bitset_iter.init_first(selected_items, out current_item_position);
        do {
            ((ConversationItemModel)selection_model.get_item (current_item_position)).node.message.set_flags (Camel.MessageFlags.FLAGGED, ~0);
            bitset_iter.next (out current_item_position);
        } while (bitset_iter.is_valid());
    }

    public void mark_unread_selected_messages () {
        var selected_items = selection_model.get_selection ();
        uint current_item_position;
        Gtk.BitsetIter bitset_iter = Gtk.BitsetIter ();
        bitset_iter.init_first(selected_items, out current_item_position);
        do {
            ((ConversationItemModel)selection_model.get_item (current_item_position)).node.message.set_flags (Camel.MessageFlags.SEEN, 0);
            bitset_iter.next (out current_item_position);
        } while (bitset_iter.is_valid());
    }

    public void mark_unstar_selected_messages () {
        var selected_items = selection_model.get_selection ();
        uint current_item_position;
        Gtk.BitsetIter bitset_iter = Gtk.BitsetIter ();
        bitset_iter.init_first(selected_items, out current_item_position);
        do {
            ((ConversationItemModel)selection_model.get_item (current_item_position)).node.message.set_flags (Camel.MessageFlags.FLAGGED, 0);
            bitset_iter.next (out current_item_position);
        } while (bitset_iter.is_valid());
    }

    // public async int archive_selected_messages () {
    //     var archive_threads = new Gee.HashMap<string, Gee.ArrayList<unowned Camel.FolderThreadNode?>> ();

    //     var selected_rows = get_selected_rows ();
    //     int selected_rows_start_index = list_store.get_index_of (selected_rows.to_array ()[0]);

    //     foreach (unowned var selected_row in selected_rows) {
    //         var selected_item_model = (ConversationItemModel) selected_row;

    //         if (archive_threads[selected_item_model.service_uid] == null) {
    //             archive_threads[selected_item_model.service_uid] = new Gee.ArrayList<unowned Camel.FolderThreadNode?> ();
    //         }

    //         archive_threads[selected_item_model.service_uid].add (selected_item_model.node);
    //     }

    //     var archived = 0;
    //     foreach (var service_uid in archive_threads.keys) {
    //         archived += yield move_handler.archive_threads (folders[service_uid], archive_threads[service_uid]);
    //     }

    //     if (archived > 0) {
    //         foreach (var service_uid in archive_threads.keys) {
    //             var threads = archive_threads[service_uid];

    //             foreach (unowned var thread in threads) {
    //                 unowned var uid = thread.message.uid;
    //                 var item = conversations[uid];
    //                 if (item != null) {
    //                     conversations.unset (uid);
    //                     list_store.remove (item);
    //                 }
    //             }
    //         }
    //     }

    //     list_store.items_changed (0, archived, list_store.get_n_items ());
    //     select_row_at_index (selected_rows_start_index);

    //     return archived;
    // }

    public int trash_selected_messages () {
        var trash_threads = new Gee.HashMap<string, Gee.ArrayList<unowned Camel.FolderThreadNode?>> ();

        var selected_items = selection_model.get_selection ();
        uint current_item_position;
        Gtk.BitsetIter bitset_iter = Gtk.BitsetIter ();
        bitset_iter.init_first(selected_items, out current_item_position);
        var selected_rows_start_index = current_item_position;
        do {
            var selected_item_model = ((ConversationItemModel)selection_model.get_item (current_item_position));

            if (trash_threads[selected_item_model.service_uid] == null) {
                trash_threads[selected_item_model.service_uid] = new Gee.ArrayList<unowned Camel.FolderThreadNode?> ();
            }

            trash_threads[selected_item_model.service_uid].add (selected_item_model.node);

            bitset_iter.next (out current_item_position);
        } while (bitset_iter.is_valid());

        var deleted = 0;
        foreach (var service_uid in trash_threads.keys) {
            deleted += move_handler.delete_threads (folders[service_uid], trash_threads[service_uid]);
        }

        list_store.items_changed (0, list_store.get_n_items (), list_store.get_n_items ());
        selection_model.select_item (selected_rows_start_index, true);

        return deleted;
    }

    public void undo_move () {
        move_handler.undo_last_move.begin ((obj, res) => {
            move_handler.undo_last_move.end (res);
        });
    }

    public void undo_expired () {
        move_handler.expire_undo ();
    }

    private void create_context_menu (double x, double y, ConversationListItem list_item) {
        var selected_items = selection_model.get_selection ();
        var menu = new Menu ();
        if (selected_items.get_size () > 1) {
            // mark all read etc
        } else if (selected_items.get_size () == 1) {
            uint current_item_position;
            Gtk.BitsetIter bitset_iter = Gtk.BitsetIter ();
            bitset_iter.init_first(selected_items, out current_item_position);
            var item = (ConversationItemModel) selection_model.get_item (current_item_position);

            menu.append(_("Move To Trash"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MOVE_TO_TRASH);
            if (!item.unread) {
                menu.append (_("Mark As Unread"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNREAD);
            } else {
                menu.append (_("Mark As Read"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_READ);
            }
            if (!item.flagged) {
                menu.append (_("Star"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_STAR);
            } else {
                menu.append (_("Unstar"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNSTAR);
            }
        }
        var popover_menu = new Gtk.PopoverMenu.from_model (menu) {
            position = RIGHT
        };
        list_item.popup_menu (popover_menu, x, y);
    }
}
