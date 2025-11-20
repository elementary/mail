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

public class Mail.ConversationList : Gtk.Box {
    public signal void conversation_selected (Camel.FolderThreadNode? node);
    public signal void conversation_focused (Camel.FolderThreadNode? node);

    private const int MARK_READ_TIMEOUT_SECONDS = 5;

    public Gee.Map<Backend.Account, Camel.FolderInfo?> folder_info_per_account { get; private set; }
    public Gee.HashMap<string, Camel.Folder> folders { get; private set; }
    public Gee.HashMap<string, Camel.FolderInfoFlags> folder_info_flags { get; private set; }
    public Hdy.HeaderBar search_header { get; private set; }

    private GLib.Cancellable? cancellable = null;
    private Gee.HashMap<string, Camel.FolderThread> threads;
    private Gee.HashMap<string, ConversationItemModel> conversations;
    private ConversationListStore list_store;
    private VirtualizingListBox list_box;
    private Gtk.SearchEntry search_entry;
    private Granite.SwitchModelButton hide_read_switch;
    private Granite.SwitchModelButton hide_unstarred_switch;
    private Gtk.MenuButton filter_button;
    private Gtk.Stack refresh_stack;

    private uint mark_read_timeout_id = 0;

    construct {
        orientation = VERTICAL;
        get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);

        conversations = new Gee.HashMap<string, ConversationItemModel> ();
        folders = new Gee.HashMap<string, Camel.Folder> ();
        folder_info_flags = new Gee.HashMap<string, Camel.FolderInfoFlags> ();
        threads = new Gee.HashMap<string, Camel.FolderThread> ();
        list_store = new ConversationListStore ();
        list_store.set_sort_func (thread_sort_function);
        list_store.set_filter_func (filter_function);

        list_box = new VirtualizingListBox () {
            activate_on_single_click = true,
            model = list_store,
            selection_mode = SINGLE
        };
        list_box.factory_func = (item, old_widget) => {
            ConversationListItem? row = null;
            if (old_widget != null) {
                row = old_widget as ConversationListItem;
            } else {
                row = new ConversationListItem ();
                row.select.connect (() => {
                    if (list_box.selected_row_widget != row) {
                        list_box.select_row (row);
                    }
                });
            }

            row.assign ((ConversationItemModel)item);
            row.show_all ();
            return row;
        };

        var application_instance = (Gtk.Application) GLib.Application.get_default ();

        search_entry = new Gtk.SearchEntry () {
            hexpand = true,
            placeholder_text = _("Search Mail"),
            valign = Gtk.Align.CENTER
        };

        hide_read_switch = new Granite.SwitchModelButton (_("Hide read conversations"));
        hide_unstarred_switch = new Granite.SwitchModelButton (_("Hide unstarred conversations"));

        var filter_menu_popover_box = new Gtk.Box (VERTICAL, 0) {
            margin_bottom = 3,
            margin_top = 3
        };
        filter_menu_popover_box.add (hide_read_switch);
        filter_menu_popover_box.add (hide_unstarred_switch);
        filter_menu_popover_box.show_all ();

        var filter_popover = new Gtk.Popover (null) {
            child = filter_menu_popover_box
        };

        filter_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("mail-filter-symbolic", Gtk.IconSize.SMALL_TOOLBAR),
            popover = filter_popover,
            tooltip_text = _("Filter Conversations"),
            valign = Gtk.Align.CENTER
        };

        search_header = new Hdy.HeaderBar () {
            custom_title = search_entry
        };
        search_header.pack_end (filter_button);
        search_header.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            width_request = 158,
            expand = true,
            child = list_box
        };

        var refresh_button = new Gtk.Button.from_icon_name ("view-refresh-symbolic", Gtk.IconSize.SMALL_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REFRESH
        };

        refresh_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (refresh_button.action_name),
            _("Fetch new messages")
        );

        var refresh_spinner = new Gtk.Spinner () {
            active = true,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            tooltip_text = _("Fetching new messages…")
        };

        refresh_stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        refresh_stack.add_named (refresh_button, "button");
        refresh_stack.add_named (refresh_spinner, "spinner");
        refresh_stack.visible_child = refresh_button;

        var move_spinner = new Gtk.Spinner () {
            active = true,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            no_show_all = true
        };
        MoveOperation.bind_spinner (move_spinner);

        var conversation_action_bar = new Gtk.ActionBar ();
        conversation_action_bar.pack_start (refresh_stack);
        conversation_action_bar.pack_end (move_spinner);
        conversation_action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        add (search_header);
        add (scrolled_window);
        add (conversation_action_bar);

        search_entry.search_changed.connect (() => load_folder.begin (folder_info_per_account));

        list_box.row_activated.connect ((row) => {
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
                        set_thread_flag (((ConversationItemModel) row).node, Camel.MessageFlags.SEEN);

                        mark_read_timeout_id = 0;
                        return false;
                    });
                }
            }
        });

        list_box.row_selected.connect ((row) => {
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

        var settings = new GLib.Settings ("io.elementary.mail");
        settings.bind ("hide-read-conversations", hide_read_switch, "active", DEFAULT);
        settings.bind ("hide-unstarred-conversations", hide_unstarred_switch, "active", DEFAULT);

        hide_read_switch.toggled.connect (() => load_folder.begin (folder_info_per_account));
        hide_unstarred_switch.toggled.connect (() => load_folder.begin (folder_info_per_account));
    }

    private static void set_thread_flag (Camel.FolderThreadNode? node, Camel.MessageFlags flag) {
        if (node == null) {
            return;
        }

        if (!(flag in (int)((Camel.MessageInfo?) node.get_item ()).flags)) {
            ((Camel.MessageInfo?) node.get_item ()).set_flags (flag, ~0);
        }

        for (unowned Camel.FolderThreadNode? child = node.get_child (); child != null; child = child.get_next ()) {
            set_thread_flag (child, flag);
        }
    }

    public async void load_folder (Gee.Map<Backend.Account, Camel.FolderInfo?> folder_info_per_account) requires (folder_info_per_account != null) {
        lock (this.folder_info_per_account) {
            this.folder_info_per_account = folder_info_per_account;
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

                    lock (this.folder_info_per_account) {
                        foreach (var folder_info_entry in this.folder_info_per_account) {
                            var current_account = folder_info_entry.key;
                            var current_folder_info = folder_info_entry.value;

                            if (current_folder_info == null) {
                                continue;
                            }

                            try {
                                var camel_store = (Camel.Store) current_account.service;

                                var folder = yield camel_store.get_folder (current_folder_info.full_name, 0, GLib.Priority.DEFAULT, cancellable);
                                folders[current_account.service.uid] = folder;

                                var info_flags = Utils.get_full_folder_info_flags (current_account.service, current_folder_info);
                                folder_info_flags[current_account.service.uid] = info_flags;

                                folder.changed.connect ((change_info) => folder_changed (change_info, current_account.service.uid, cancellable));

                                var search_result_uids = get_search_result_uids (current_account.service.uid);
                                if (search_result_uids != null) {
                                    var thread = new Camel.FolderThread (folder, (GLib.GenericArray<string>?) search_result_uids, Camel.FolderThreadFlags.NONE);
                                    threads[current_account.service.uid] = thread;

                                    weak Camel.FolderThreadNode? child = thread.get_tree ();
                                    while (child != null) {
                                        if (cancellable.is_cancelled ()) {
                                            break;
                                        }

                                        add_conversation_item (folder_info_flags[current_account.service.uid], child, thread, current_account.service.uid);
                                        child = child.get_next ();
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

        list_store.items_changed (0, 0, list_store.get_n_items ());
    }

    public async void refresh_folder (GLib.Cancellable? cancellable = null) {
        refresh_stack.set_visible_child_name ("spinner");
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
        refresh_stack.set_visible_child_name ("button");
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

                threads[service_uid] = new Camel.FolderThread (folders[service_uid], (GLib.GenericArray<string>?) search_result_uids, Camel.FolderThreadFlags.NONE);

                var removed = 0;
                change_info.get_removed_uids ().foreach ((uid) => {
                    var item = conversations[uid];
                    if (item != null) {
                        conversations.unset (uid);
                        list_store.remove (item);
                        removed++;
                    }
                });

                unowned Camel.FolderThreadNode? child = threads[service_uid].get_tree ();
                while (child != null) {
                    if (cancellable.is_cancelled ()) {
                        return;
                    }

                    var item = conversations[((Camel.MessageInfo?) child.get_item ()).uid];
                    if (item == null) {
                        add_conversation_item (folder_info_flags[service_uid], child, threads[service_uid], service_uid);
                    } else {
                        if (item.is_older_than (child)) {
                            conversations.unset (((Camel.MessageInfo?) child.get_item ()).uid);
                            list_store.remove (item);
                            removed++;
                            add_conversation_item (folder_info_flags[service_uid], child, threads[service_uid], service_uid);
                        };
                    }

                    child = child.get_next ();
                }

                list_store.items_changed (0, removed, list_store.get_n_items ());
            }
        }
    }

    private GenericArray<weak string>? get_search_result_uids (string service_uid) {
        var style_context = filter_button.get_style_context ();
        if (hide_read_switch.active || hide_unstarred_switch.active) {
            if (!style_context.has_class (Granite.STYLE_CLASS_ACCENT)) {
                style_context.add_class (Granite.STYLE_CLASS_ACCENT);
            }
        } else if (style_context.has_class (Granite.STYLE_CLASS_ACCENT)) {
            style_context.remove_class (Granite.STYLE_CLASS_ACCENT);
        }

        lock (folders) {
            if (folders[service_uid] == null) {
                return null;
            }

            var has_current_search_query = search_entry.text.strip () != "";
            if (!has_current_search_query && !hide_read_switch.active && !hide_unstarred_switch.active) {
                return folders[service_uid].dup_uids ();
            }

            string[] current_search_expressions = {};

            if (hide_read_switch.active) {
                current_search_expressions += """(not (system-flag "Seen"))""";
            }

            if (hide_unstarred_switch.active) {
                current_search_expressions += """(system-flag "Flagged")""";
            }

            if (has_current_search_query) {
                var sb = new StringBuilder ();
                Camel.SExp.encode_string (sb, search_entry.text);
                var encoded_query = sb.str;

                current_search_expressions += """(or (header-contains "From" %s)(header-contains "Subject" %s)(body-contains %s))"""
                .printf (encoded_query, encoded_query, encoded_query);
            }

            string search_query = "(match-all (and " + string.joinv ("", current_search_expressions) + "))";

            try {
                GenericArray<weak string>? uids = null;
                folders[service_uid].search_sync (search_query, out uids, cancellable);
                return uids;
            } catch (Error e) {
                if (!(e is GLib.IOError.CANCELLED)) {
                    warning ("Error while searching: %s", e.message);
                }

                return folders[service_uid].dup_uids ();
            }
        }
    }

    private void add_conversation_item (Camel.FolderInfoFlags folder_info_flags, Camel.FolderThreadNode child, Camel.FolderThread thread, string service_uid) {
        var item = new ConversationItemModel (folder_info_flags, child, thread, service_uid);
        conversations[((Camel.MessageInfo?) child.get_item ()).uid] = item;
        list_store.add (item);
    }

    private static bool filter_function (GLib.Object obj) {
        if (obj is ConversationItemModel) {
            var conversation_item = (ConversationItemModel)obj;
            return !conversation_item.deleted && !conversation_item.hidden;
        } else {
            return false;
        }
    }

    private static int thread_sort_function (ConversationItemModel item1, ConversationItemModel item2) {
        return (int)(item2.timestamp - item1.timestamp);
    }

    public void mark_read_selected_messages () {
        var selected_rows = list_box.get_selected_rows ();
        foreach (var row in selected_rows) {
            ((Camel.MessageInfo?) (((ConversationItemModel)row).node).get_item ()).set_flags (Camel.MessageFlags.SEEN, ~0);
        }
    }

    public void mark_star_selected_messages () {
        var selected_rows = list_box.get_selected_rows ();
        foreach (var row in selected_rows) {
            ((Camel.MessageInfo?) (((ConversationItemModel)row).node).get_item ()).set_flags (Camel.MessageFlags.FLAGGED, ~0);
        }
    }

    public void mark_unread_selected_messages () {
        var selected_rows = list_box.get_selected_rows ();
        foreach (var row in selected_rows) {
            ((Camel.MessageInfo?) (((ConversationItemModel)row).node).get_item ()).set_flags (Camel.MessageFlags.SEEN, 0);
        }
    }

    public void mark_unstar_selected_messages () {
        var selected_rows = list_box.get_selected_rows ();
        foreach (var row in selected_rows) {
            ((Camel.MessageInfo?) (((ConversationItemModel)row).node).get_item ()).set_flags (Camel.MessageFlags.FLAGGED, 0);
        }
    }

    public async uint move_selected_messages (MoveOperation.MoveType move_type, Variant? dst_folder_full_name = null, out string error_message) {
        error_message = "";
        ConversationItemModel[] moved_conversation_items = {};
        var move_threads = new Gee.HashMap<string, Gee.ArrayList<unowned Camel.FolderThreadNode?>> ();

        var selected_rows = list_box.get_selected_rows ();
        int selected_rows_start_index = list_store.get_index_of (selected_rows.to_array ()[0]);

        foreach (unowned var selected_row in selected_rows) {
            var selected_item_model = (ConversationItemModel) selected_row;
            selected_item_model.hidden = true;
            moved_conversation_items += selected_item_model;

            if (move_threads[selected_item_model.service_uid] == null) {
                move_threads[selected_item_model.service_uid] = new Gee.ArrayList<unowned Camel.FolderThreadNode?> ();
            }

            move_threads[selected_item_model.service_uid].add (selected_item_model.node);
        }

        list_store.items_changed (0, list_store.get_n_items (), list_store.get_n_items ());
        list_box.select_row_at_index (selected_rows_start_index + 1);

        uint moved = 0;
        foreach (var service_uid in move_threads.keys) {
            try {
                uint n_messages_moved;
                var move_operation = yield new MoveOperation (folders[service_uid], move_type, move_threads[service_uid], dst_folder_full_name, out n_messages_moved);
                move_operation.undone.connect (() => unhide_conversations (moved_conversation_items));

                moved += n_messages_moved;
            } catch (Error e) {
                warning ("Failed to prepare move operation: %s", e.message);
                error_message = e.message;
            }
        }

        if (error_message != "") {
            unhide_conversations (moved_conversation_items);
        }

        return moved;
    }

    private void unhide_conversations (ConversationItemModel[] moved_conversation_items) {
        foreach (var item in moved_conversation_items) {
            item.hidden = false;
        }

        list_store.items_changed (0, list_store.get_n_items (), list_store.get_n_items ());
    }
}
