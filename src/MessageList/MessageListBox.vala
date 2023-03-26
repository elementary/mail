// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.MessageListBox : Gtk.Box {
    public signal void hovering_over_link (string? label, string? uri);
    public bool can_reply { get; set; default = false; }
    public bool can_move_thread { get; set; default = false; }
    public GenericArray<string> uids { get; private set; default = new GenericArray<string> (); }

    public Gtk.HeaderBar header_bar;
    public Gtk.ListBox list_box;
    public Gtk.ScrolledWindow scrolled_window;

    public MessageListBox () {
    }

    construct {
        orientation = VERTICAL;
        spacing = 0;

        header_bar = new Gtk.HeaderBar () {
            show_title_buttons = false,
            title_widget = new Gtk.Label ("")
        };
        header_bar.add_css_class (Granite.STYLE_CLASS_FLAT);

        var window_controls_end = new Gtk.WindowControls (END);

        var load_images_menuitem = new Granite.SwitchModelButton (_("Always Show Remote Images"));

        var account_settings_menuitem = new Gtk.Button.with_label (_("Account Settings…"));
        account_settings_menuitem.add_css_class (Granite.STYLE_CLASS_MENUITEM);

        var app_menu_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
            margin_bottom = 3,
            margin_top = 3
        };

        var app_menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_bottom = 3,
            margin_top = 3
        };
        app_menu_box.append (load_images_menuitem);
        app_menu_box.append (app_menu_separator);
        app_menu_box.append (account_settings_menuitem);

        var app_menu_popover = new Gtk.Popover () {
            child = app_menu_box
        };
        app_menu_popover.add_css_class (Granite.STYLE_CLASS_MENU);

        var app_menu = new Gtk.MenuButton () {
            icon_name = "open-menu",
            popover = app_menu_popover,
            tooltip_text = _("Menu"),
            halign = END
        };
        //app_menu.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var application_instance = (Gtk.Application) GLib.Application.get_default ();
        var reply_button = new Gtk.Button.from_icon_name ("mail-reply-sender");
        reply_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REPLY;
        reply_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (reply_button.action_name),
            _("Reply")
        );
        //reply_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var reply_all_button = new Gtk.Button.from_icon_name ("mail-reply-all");
        reply_all_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REPLY_ALL;
        reply_all_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (reply_all_button.action_name),
            _("Reply All")
        );
        //reply_all_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var forward_button = new Gtk.Button.from_icon_name ("mail-forward");
        forward_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_FORWARD;
        forward_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (forward_button.action_name),
            _("Forward")
        );
        //forward_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var mark_menu = new Gtk.Popover ();
        mark_menu.add_css_class (Granite.STYLE_CLASS_MENU);

        var mark_unread_item = new Gtk.Button () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNREAD,
            child = new Granite.AccelLabel.from_action_name (_("Mark as Unread"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNREAD)
        };
        mark_unread_item.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        mark_unread_item.bind_property ("sensitive", mark_unread_item, "visible", BindingFlags.SYNC_CREATE);
        mark_unread_item.clicked.connect (() => {
            mark_menu.popdown ();
        });

        var mark_read_item = new Gtk.Button () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_READ,
            child = new Granite.AccelLabel.from_action_name (_("Mark as Read"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_READ)
        };
        mark_read_item.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        mark_read_item.bind_property ("sensitive", mark_read_item, "visible", BindingFlags.SYNC_CREATE);
        mark_read_item.clicked.connect (() => {
            mark_menu.popdown ();
        });

        var mark_star_item = new Gtk.Button () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_STAR,
            child = new Granite.AccelLabel.from_action_name (_("Star"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_STAR)
        };
        mark_star_item.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        mark_star_item.bind_property ("sensitive", mark_star_item, "visible", BindingFlags.SYNC_CREATE);
        mark_star_item.clicked.connect (() => {
            mark_menu.popdown ();
        });

        var mark_unstar_item = new Gtk.Button () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNSTAR,
            child = new Granite.AccelLabel.from_action_name (_("Unstar"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNSTAR)
        };
        mark_unstar_item.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        mark_unstar_item.bind_property ("sensitive", mark_unstar_item, "visible", BindingFlags.SYNC_CREATE);
        mark_unstar_item.clicked.connect (() => {
            mark_menu.popdown ();
        });

        var mark_menu_box = new Gtk.Box (VERTICAL, 0);
        mark_menu_box.append (mark_unread_item);
        mark_menu_box.append (mark_read_item);
        mark_menu_box.append (mark_star_item);
        mark_menu_box.append (mark_unstar_item);

        mark_menu.set_child (mark_menu_box);

        var mark_menu_button = new Gtk.MenuButton () {
            icon_name = "edit-mark",
            popover = mark_menu,
            tooltip_text = _("Mark Conversation")
        };
        //mark_menu_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        bind_property ("can-move-thread", mark_menu_button, "sensitive", BindingFlags.SYNC_CREATE);

        var archive_button = new Gtk.Button.from_icon_name ("mail-archive");
        archive_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ARCHIVE;
        archive_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (archive_button.action_name),
            _("Move conversations to archive")
        );
        //archive_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var trash_button = new Gtk.Button.from_icon_name ("edit-delete");
        trash_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MOVE_TO_TRASH;
        trash_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (trash_button.action_name),
            _("Move conversations to Trash")
        );

        header_bar.pack_start (reply_button);
        header_bar.pack_start (reply_all_button);
        header_bar.pack_start (forward_button);
        header_bar.pack_start (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        header_bar.pack_start (mark_menu_button);
        header_bar.pack_start (archive_button);
        header_bar.pack_start (trash_button);
        header_bar.pack_end (window_controls_end);
        header_bar.pack_end (app_menu);

        var settings = new GLib.Settings ("io.elementary.mail");
        settings.bind ("always-load-remote-images", load_images_menuitem, "active", SettingsBindFlags.DEFAULT);

        account_settings_menuitem.clicked.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://accounts/online", null);
            } catch (Error e) {
                warning ("Failed to open account settings: %s", e.message);
            }
            app_menu_popover.popdown ();
        });

        list_box = new Gtk.ListBox () {
            hexpand = true,
            vexpand = true
        };
        list_box.selection_mode = NONE;
        scrolled_window = new Gtk.ScrolledWindow () {
            hexpand = true,
            vexpand = true,
            child = list_box,
            hscrollbar_policy = NEVER
        };

        var view_overlay = new Gtk.Overlay ();
        view_overlay.set_child (scrolled_window);

        var message_overlay = new Granite.OverlayBar (view_overlay);

        hovering_over_link.connect ((label, url) => {
            var hover_url = url != null ? GLib.Uri.unescape_string (url) : null;
            if (hover_url == null) {
                message_overlay.hide ();
            } else {
                message_overlay.label = hover_url;
                message_overlay.show ();
            }
        });

        this.append (header_bar);
        this.append (view_overlay);

        var placeholder = new Gtk.Label (_("No Message Selected"));
        placeholder.visible = true;
        placeholder.add_css_class (Granite.STYLE_CLASS_H2_LABEL);
        placeholder.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        //add_css_class (Granite.STYLE_CLASS_BACKGROUND);
        list_box.set_placeholder (placeholder);
        list_box.set_sort_func (message_sort_function);
    }

    public void set_conversation (Camel.FolderThreadNode? node) {
        /*
         * Prevent the user from interacting with the message thread while it
         * is being reloaded. can_reply will be set to true after loading the
         * thread.
         */
        can_reply = false;
        can_move_thread = false;

        var current_child = list_box.get_row_at_index (0);
        for (int i = 0; current_child != null; i++) {
            list_box.remove (current_child);
            current_child.destroy ();
            current_child = list_box.get_row_at_index (i);
        }

        uids = new GenericArray<string> ();

        if (node == null) {
            return;
        }

        /*
         * If there is a node, we can move the thread even without loading all
         * individual messages.
         */
        can_move_thread = true;

        var item = new MessageListItem (node.message, this);
        list_box.append (item);
        uids.add (node.message.uid);
        if (node.child != null) {
            go_down ((Camel.FolderThreadNode?) node.child);
        }

        var child = list_box.get_last_child ().get_prev_sibling (); //The last child is the placeholder
        if (child != null && child is MessageListItem) {
            var list_item = (MessageListItem) child;
            list_item.expanded = true;
            list_item.bind_property ("loaded", this, "can-reply", BindingFlags.SYNC_CREATE);
        }
    }

    private void go_down (Camel.FolderThreadNode node) {
        unowned Camel.FolderThreadNode? current_node = node;
        while (current_node != null) {
            var item = new MessageListItem (current_node.message, this);
            list_box.append (item);
            uids.add (current_node.message.uid);
            if (current_node.next != null) {
                go_down ((Camel.FolderThreadNode?) current_node.next);
            }

            current_node = (Camel.FolderThreadNode?) current_node.child;
        }
    }

    public async void add_inline_composer (ComposerWidget.Type type, MessageListItem? message_item = null) {
        /* Can't open a new composer if thread is empty or currently has a composer open */
        var last_child = list_box.get_last_child ().get_prev_sibling (); //The last child is the placeholder
        if (last_child == null || last_child is InlineComposer) {
            return;
        }

        if (message_item == null) {
            message_item = (MessageListItem) last_child;
        }

        string content_to_quote = "";
        Camel.MimeMessage? mime_message = null;
        Camel.MessageInfo? message_info = null;
        content_to_quote = yield message_item.get_message_body_html ();
        mime_message = message_item.mime_message;
        message_info = message_item.message_info;

        var composer = new InlineComposer (type, message_info, mime_message, content_to_quote);
        composer.discarded.connect (() => {
            can_reply = true;
            can_move_thread = true;
            list_box.remove (composer);
            composer.destroy ();
        });
        list_box.append (composer);
        can_reply = false;
        can_move_thread = true;
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

