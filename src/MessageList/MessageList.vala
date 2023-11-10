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
    private Gtk.ListBox list_box;
    private Gtk.Paned vpaned;
    private Gtk.Frame web_view_frame;
    private Gee.HashMap<string, MessageListItem> messages;

    construct {
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

        var mark_unread_item = new Gtk.MenuItem () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNREAD
        };
        mark_unread_item.bind_property ("sensitive", mark_unread_item, "visible");
        mark_unread_item.add (new Granite.AccelLabel.from_action_name (_("Mark as Unread"), mark_unread_item.action_name));

        var mark_read_item = new Gtk.MenuItem () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_READ
        };
        mark_read_item.bind_property ("sensitive", mark_read_item, "visible");
        mark_read_item.add (new Granite.AccelLabel.from_action_name (_("Mark as Read"), mark_read_item.action_name));

        var mark_star_item = new Gtk.MenuItem () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_STAR
        };
        mark_star_item.bind_property ("sensitive", mark_star_item, "visible");
        mark_star_item.add (new Granite.AccelLabel.from_action_name (_("Star"), mark_star_item.action_name));

        var mark_unstar_item = new Gtk.MenuItem () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNSTAR
        };
        mark_unstar_item.bind_property ("sensitive", mark_unstar_item, "visible");
        mark_unstar_item.add (new Granite.AccelLabel.from_action_name (_("Unstar"), mark_unstar_item.action_name));

        var mark_menu = new Gtk.Menu ();
        mark_menu.add (mark_unread_item);
        mark_menu.add (mark_read_item);
        mark_menu.add (mark_star_item);
        mark_menu.add (mark_unstar_item);
        mark_menu.show_all ();

        var mark_button = new Gtk.MenuButton () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MODIFY,
            image = new Gtk.Image.from_icon_name ("edit-mark", Gtk.IconSize.LARGE_TOOLBAR),
            popup = mark_menu,
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

        list_box = new Gtk.ListBox () {
            hexpand = true,
            vexpand = true,
            selection_mode = NONE
        };

        list_box.get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);
        list_box.set_placeholder (placeholder);
        list_box.set_sort_func (message_sort_function);

        vpaned = new Gtk.Paned (Gtk.Orientation.VERTICAL);
        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = NEVER,
            min_content_height = 150
        };
        scrolled_window.add (list_box);

        web_view_frame = new Gtk.Frame ("") {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12,
            shadow_type = Gtk.ShadowType.ETCHED_IN
        };

        vpaned.pack1 (scrolled_window, false, false);
        vpaned.pack2 (web_view_frame, true, true);

        orientation = VERTICAL;
        add (headerbar);
        add (vpaned);
        show_all ();
    }

    private Gtk.Widget? view_widget = null;
    public void row_expand_changed (Mail.MessageListItem row) {
        if (view_widget != null) {
            web_view_frame.remove (view_widget);
        }

        if (row.expanded) {
            var index = 0;
            while (list_box.get_row_at_index (index) != null) {
                var rw = (Mail.MessageListItem) list_box.get_row_at_index (index);
                if (rw != row) {
                    rw.expanded = false;
                }

                index++;
            }

            view_widget = row.web_view;
            web_view_frame.add (view_widget);
            row.web_view.show_all ();
        }
    }

    public void set_conversation (Camel.FolderThreadNode? node) {
        /*
         * Prevent the user from interacting with the message thread while it
         * is being reloaded. can_reply will be set to true after loading the
         * thread.
         */
        can_reply (false);
        can_move_thread (false);

        list_box.get_children ().foreach ((child) => {
            child.destroy ();
        });
        messages = new Gee.HashMap<string, MessageListItem> (null, null);

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

        var item = new MessageListItem (node.message, this);
        list_box.add (item);
        messages.set (node.message.uid, item);
        if (node.child != null) {
            go_down ((Camel.FolderThreadNode?) node.child);
        }

        var children = list_box.get_children ();
        var num_children = children.length ();
        if (num_children > 0) {
            var child = list_box.get_row_at_index ((int) num_children - 1);
            if (child != null && child is MessageListItem) {
                var list_item = (MessageListItem) child;
                list_item.expanded = true;
                can_reply (list_item.loaded);
                list_item.notify["loaded"].connect (() => {
                    can_reply (list_item.loaded);
                });
            }
        }

        if (node.message != null && Camel.MessageFlags.DRAFT in (int) node.message.flags) {
            compose.begin (Composer.Type.DRAFT, "");
        }
    }

    private void go_down (Camel.FolderThreadNode node) {
        unowned Camel.FolderThreadNode? current_node = node;
        while (current_node != null) {
            var item = new MessageListItem (current_node.message, this);
            list_box.add (item);
            messages.set (current_node.message.uid, item);
            if (current_node.next != null) {
                go_down ((Camel.FolderThreadNode?) current_node.next);
            }

            current_node = (Camel.FolderThreadNode?) current_node.child;
        }
    }

    public async void compose (Composer.Type type, Variant uid) {
        /* Can't open a new composer if thread is empty*/
        var last_child = list_box.get_row_at_index ((int) list_box.get_children ().length () - 1);
        if (last_child == null) {
            return;
        }

        MessageListItem message_item = null;

        if (uid.get_string () == "") {
            message_item = (MessageListItem) last_child;
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

    private static int message_sort_function (Gtk.ListBoxRow item1, Gtk.ListBoxRow item2) {
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
