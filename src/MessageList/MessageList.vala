/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017-2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.MessageList : Gtk.Box {
    public signal void hovering_over_link (string? label, string? uri);
    public Hdy.HeaderBar headerbar { get; private set; }

    private FolderPopover folder_popover;
    private Gee.HashMap<string, MessageListItem> messages;
    private ListStore message_list;

    construct {
        message_list = new ListStore (typeof (MessageListItem));

        get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);

        var application_instance = (Gtk.Application) GLib.Application.get_default ();

        var reply_button = new Gtk.Button.from_icon_name ("mail-reply-sender", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REPLY,
            action_target = ""
        };
        reply_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (reply_button.action_name + "::"),
            _("Reply")
        );

        var reply_all_button = new Gtk.Button.from_icon_name ("mail-reply-all", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REPLY_ALL,
            action_target = ""
        };
        reply_all_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (reply_all_button.action_name + "::"),
            _("Reply All")
        );

        var forward_button = new Gtk.Button.from_icon_name ("mail-forward", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_FORWARD,
            action_target = ""
        };
        forward_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (forward_button.action_name + "::"),
            _("Forward")
        );

        var mark_menumodel = new Menu ();
        mark_menumodel.append (_("Mark as Unread"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNREAD);
        mark_menumodel.append (_("Mark as Read"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_READ);
        mark_menumodel.append (_("Star"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_STAR);
        mark_menumodel.append (_("Unstar"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNSTAR);

        var mark_button = new Gtk.MenuButton () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MODIFY,
            image = new Gtk.Image.from_icon_name ("edit-mark", Gtk.IconSize.LARGE_TOOLBAR),
            menu_model = mark_menumodel,
            use_popover = false,
            tooltip_text = _("Mark Conversation")
        };

        folder_popover = new FolderPopover ();

        var move_button = new Gtk.MenuButton () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MODIFY,
            image = new Gtk.Image.from_icon_name ("mail-move", Gtk.IconSize.LARGE_TOOLBAR),
            tooltip_text = _("Move Conversation to…"),
            popover = folder_popover
        };

        var archive_button = new Gtk.Button.from_icon_name ("mail-archive", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ARCHIVE
        };
        archive_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (archive_button.action_name),
            _("Move conversations to archive")
        );

        var trash_button = new Gtk.Button.from_icon_name ("edit-delete", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MOVE_TO_TRASH
        };
        trash_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (trash_button.action_name),
            _("Move conversations to Trash")
        );

        headerbar = new Hdy.HeaderBar () {
            show_close_button = true
        };
        headerbar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        headerbar.pack_start (reply_button);
        headerbar.pack_start (reply_all_button);
        headerbar.pack_start (forward_button);
        headerbar.pack_end (trash_button);
        headerbar.pack_end (archive_button);
        headerbar.pack_end (move_button);
        headerbar.pack_end (mark_button);

        var placeholder = new Gtk.Label (_("No Message Selected")) {
            visible = true
        };

        var placeholder_style_context = placeholder.get_style_context ();
        placeholder_style_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
        placeholder_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var list_box = new Gtk.ListBox () {
            hexpand = true,
            vexpand = true,
            selection_mode = NONE
        };
        list_box.bind_model (message_list, (obj) => (MessageListItem) obj);

        list_box.get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);
        list_box.set_placeholder (placeholder);

        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            child = list_box,
            hscrollbar_policy = NEVER
        };

        // Prevent the focus of the webview causing the ScrolledWindow to scroll
        var scrolled_child = scrolled_window.get_child ();
        if (scrolled_child is Gtk.Container) {
            ((Gtk.Container) scrolled_child).set_focus_vadjustment (new Gtk.Adjustment (0, 0, 0, 0, 0, 0));
        }

        orientation = VERTICAL;
        add (headerbar);
        add (scrolled_window);
    }

    public void set_conversation (Camel.FolderThreadNode? node) {
        /*
         * Prevent the user from interacting with the message thread while it
         * is being reloaded. can_reply will be set to true after loading the
         * thread.
         */
        can_reply (false);
        can_move_thread (false);

        messages = new Gee.HashMap<string, MessageListItem> (null, null);
        message_list.remove_all ();

        if (node == null) {
            return;
        }

        /*
         * If there is a node, we can move the thread even without loading all
         * individual messages.
         */
        can_move_thread (true);

        var store = node.message.summary.folder.parent_store;
        folder_popover.set_store (store);

        var item = new MessageListItem (node.message);

        messages.set (node.message.uid, item);
        message_list.insert_sorted (item, message_sort_function);

        if (node.child != null) {
            go_down ((Camel.FolderThreadNode?) node.child);
        }

        if (message_list.n_items > 0) {
            var last_item = (MessageListItem) message_list.get_item (message_list.n_items - 1);
            last_item.expanded = true;
            can_reply (last_item.loaded);
            last_item.notify["loaded"].connect (() => {
                can_reply (last_item.loaded);
            });
        }

        if (node.message != null && Camel.MessageFlags.DRAFT in (int) node.message.flags) {
            compose.begin (Composer.Type.DRAFT, "");
        }
    }

    private void go_down (Camel.FolderThreadNode node) {
        unowned Camel.FolderThreadNode? current_node = node;
        while (current_node != null) {
            var item = new MessageListItem (current_node.message);

            messages.set (current_node.message.uid, item);
            message_list.insert_sorted (item, message_sort_function);

            if (current_node.next != null) {
                go_down ((Camel.FolderThreadNode?) current_node.next);
            }

            current_node = (Camel.FolderThreadNode?) current_node.child;
        }
    }

    public async void compose (Composer.Type type, Variant uid) {
        /* Can't open a new composer if thread is empty*/
        if (message_list.n_items == 0) {
            return;
        }

        MessageListItem message_item = null;

        if (uid.get_string () == "") {
            message_item = (MessageListItem) message_list.get_item (message_list.n_items - 1);
        } else {
            message_item = messages.get (uid.get_string ());
        }

        string content_to_quote = "";
        Camel.MimeMessage? mime_message = null;
        Camel.MessageInfo? message_info = null;
        content_to_quote = yield message_item.get_message_body_html ();
        mime_message = message_item.mime_message;
        message_info = message_item.message_info;

        var composer = new Composer.with_quote (type, message_info, mime_message, content_to_quote);
        composer.present ();
        composer.finished.connect (() => {
            can_reply (true);
            can_move_thread (true);
        });
        can_reply (false);
        can_move_thread (true);
    }

    public void print (Variant uid) {
        messages.get (uid.get_string ()).print ();
    }

    private void can_reply (bool enabled) {
        unowned var main_window = (Gtk.ApplicationWindow) get_toplevel ();
        ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_FORWARD)).set_enabled (enabled);
        ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_REPLY_ALL)).set_enabled (enabled);
        ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_REPLY)).set_enabled (enabled);
    }

    private void can_move_thread (bool enabled) {
        unowned var main_window = (Gtk.ApplicationWindow) get_toplevel ();
        ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_MODIFY)).set_enabled (enabled);
        ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_ARCHIVE)).set_enabled (enabled);
        ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_MOVE)).set_enabled (enabled);
        ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_MOVE_TO_TRASH)).set_enabled (enabled);
    }

    private static int message_sort_function (Object item1, Object item2) {
        unowned MessageListItem message1 = (MessageListItem)item1;
        unowned MessageListItem message2 = (MessageListItem)item2;

        var timestamp1 = message1.message_info.date_received;
        if (timestamp1 == 0) {
            timestamp1 = message1.message_info.date_sent;
        }

        var timestamp2 = message2.message_info.date_received;
        if (timestamp2 == 0) {
            timestamp2 = message2.message_info.date_sent;
        }

        return (int)(timestamp1 - timestamp2);
    }
}
