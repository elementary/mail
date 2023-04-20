/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017-2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.MessageList : Gtk.Box {
    public signal void hovering_over_link (string? label, string? uri);
    public Gtk.WindowControls window_controls { get; set; }
    public Gtk.HeaderBar headerbar { get; private set; }

    private Gtk.PopoverMenu mark_popover;
    private Gtk.ListBox list_box;
    private Gtk.ScrolledWindow scrolled_window;
    private Gee.HashMap<string, MessageListItem> messages;

    construct {
        add_css_class (Granite.STYLE_CLASS_BACKGROUND);

        var application_instance = (Gtk.Application) GLib.Application.get_default ();

        var load_images_menuitem = new Granite.SwitchModelButton (_("Always Show Remote Images"));

        var account_settings_menuitem = new Gtk.Button () {
            label = _("Account Settings…")
        };
        account_settings_menuitem.add_css_class (Granite.STYLE_CLASS_MENUITEM);

        var app_menu_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
            margin_bottom = 3,
            margin_top = 3
        };

        var app_menu_box = new Gtk.Box (VERTICAL, 0) {
            margin_bottom = 3,
            margin_top = 3
        };
        app_menu_box.append (load_images_menuitem);
        app_menu_box.append (app_menu_separator);
        app_menu_box.append (account_settings_menuitem);

        var app_menu_popover = new Gtk.Popover ();
        app_menu_popover.set_child (app_menu_box);

        var app_menu = new Gtk.MenuButton () {
            icon_name = "open-menu",
            popover = app_menu_popover,
            tooltip_text = _("Menu")
        };
        app_menu.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var reply_button = new Gtk.Button.from_icon_name ("mail-reply-sender") { //Large toolbar
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REPLY,
            action_target = ""
        };
        reply_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (reply_button.action_name + "::"),
            _("Reply")
        );
        reply_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var reply_all_button = new Gtk.Button.from_icon_name ("mail-reply-all") { //Large toolbar
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REPLY_ALL,
            action_target = ""
        };
        reply_all_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (reply_all_button.action_name + "::"),
            _("Reply All")
        );
        reply_all_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var forward_button = new Gtk.Button.from_icon_name ("mail-forward") { //Large toolbar
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_FORWARD,
            action_target = ""
        };
        forward_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (forward_button.action_name + "::"),
            _("Forward")
        );
        forward_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var mark_button = new Gtk.Button () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK,
            icon_name = "edit-mark",
            tooltip_text = _("Mark Conversation")
        };
        mark_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        mark_popover = new Gtk.PopoverMenu.from_model (null);
        mark_popover.set_parent (mark_button);

        var archive_button = new Gtk.Button.from_icon_name ("mail-archive") { //Large toolbar
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ARCHIVE
        };
        archive_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (archive_button.action_name),
            _("Move conversations to archive")
        );
        archive_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var trash_button = new Gtk.Button.from_icon_name ("edit-delete") {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MOVE_TO_TRASH
        };
        trash_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (trash_button.action_name),
            _("Move conversations to Trash")
        );
        trash_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        window_controls = new Gtk.WindowControls (END);

        headerbar = new Gtk.HeaderBar () {
            show_title_buttons = false,
            title_widget = new Gtk.Label ("")
        };
        headerbar.add_css_class (Granite.STYLE_CLASS_FLAT);
        headerbar.pack_start (reply_button);
        headerbar.pack_start (reply_all_button);
        headerbar.pack_start (forward_button);
        headerbar.pack_start (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        headerbar.pack_start (mark_button);
        headerbar.pack_start (archive_button);
        headerbar.pack_start (trash_button);
        headerbar.pack_end (window_controls);
        headerbar.pack_end (app_menu);

        var placeholder = new Gtk.Label (_("No Message Selected")) {
            visible = true
        };
        placeholder.add_css_class (Granite.STYLE_CLASS_H2_LABEL);
        placeholder.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        list_box = new Gtk.ListBox () {
            hexpand = true,
            vexpand = true,
            selection_mode = NONE
        };
        list_box.add_css_class (Granite.STYLE_CLASS_BACKGROUND);
        list_box.set_placeholder (placeholder);
        list_box.set_sort_func (message_sort_function);

        scrolled_window = new Gtk.ScrolledWindow () {
            hscrollbar_policy = NEVER
        };
        scrolled_window.set_child (list_box);

        // Prevent the focus of the webview causing the ScrolledWindow to scroll. @TODO: correct replacement?
        var scrolled_child = scrolled_window.get_child ();
        if (scrolled_child is Gtk.Viewport) {
            ((Gtk.Viewport) scrolled_child).scroll_to_focus = true;
        }

        orientation = VERTICAL;
        append (headerbar);
        append (scrolled_window);

        var settings = new GLib.Settings ("io.elementary.mail");
        settings.bind ("always-load-remote-images", load_images_menuitem, "active", SettingsBindFlags.DEFAULT);

        account_settings_menuitem.clicked.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://accounts/online", null);
            } catch (Error e) {
                warning ("Failed to open account settings: %s", e.message);
            }
        });

        mark_button.clicked.connect (create_context_menu);
    }

    public void create_context_menu () {
        unowned var main_window = (MainWindow) get_root ();
        var mark_menu = new Menu ();

        if (main_window.get_action (MainWindow.ACTION_MARK_UNREAD).enabled) {
            mark_menu.append (_("Mark as Unread"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNREAD);
        } else {
            mark_menu.append (_("Mark as Read"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_READ);
        }

        if (main_window.get_action (MainWindow.ACTION_MARK_STAR).enabled) {
            mark_menu.append (_("Star"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_STAR);
        } else {
            mark_menu.append (_("Unstar"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNSTAR);
        }

        mark_popover.set_menu_model (mark_menu);
        mark_popover.popup ();
    }

    public void set_conversation (Camel.FolderThreadNode? node) {
        /*
         * Prevent the user from interacting with the message thread while it
         * is being reloaded. can_reply will be set to true after loading the
         * thread.
         */
        can_reply (false);
        can_move_thread (false);

        var current_child = list_box.get_row_at_index (0);
        for (int i = 0; current_child != null; i++) {
            list_box.remove (current_child);
            current_child = list_box.get_row_at_index (i);
        }

        messages = new Gee.HashMap<string, MessageListItem> (null, null);

        if (node == null) {
            return;
        }

        /*
         * If there is a node, we can move the thread even without loading all
         * individual messages.
         */
        can_move_thread (true);

        var item = new MessageListItem (node.message);
        list_box.append (item);
        messages.set (node.message.uid, item);
        if (node.child != null) {
            go_down ((Camel.FolderThreadNode?) node.child);
        }

        var child = list_box.get_last_child ().get_prev_sibling (); //The last child is the placeholder
        if (child != null && child is MessageListItem) {
            var list_item = (MessageListItem) child;
            list_item.expanded = true;
            can_reply (list_item.loaded);
            list_item.notify["loaded"].connect (() => {
                can_reply (list_item.loaded);
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
            list_box.append (item);
            messages.set (current_node.message.uid, item);
            if (current_node.next != null) {
                go_down ((Camel.FolderThreadNode?) current_node.next);
            }

            current_node = (Camel.FolderThreadNode?) current_node.child;
        }
    }

    public async void compose (Composer.Type type, Variant uid) {
        /* Can't open a new composer if thread is empty*/
        var last_child = list_box.get_last_child ().get_prev_sibling (); //The last child is the placeholder
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
        unowned var main_window = (MainWindow) get_root ();
        main_window.get_action (MainWindow.ACTION_FORWARD).set_enabled (enabled);
        main_window.get_action (MainWindow.ACTION_REPLY_ALL).set_enabled (enabled);
        main_window.get_action (MainWindow.ACTION_REPLY).set_enabled (enabled);
    }

    private void can_move_thread (bool enabled) {
        unowned var main_window = (MainWindow) get_root ();
        main_window.get_action (MainWindow.ACTION_ARCHIVE).set_enabled (enabled);
        main_window.get_action (MainWindow.ACTION_MARK).set_enabled (enabled);
        main_window.get_action (MainWindow.ACTION_MOVE_TO_TRASH).set_enabled (enabled);
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
