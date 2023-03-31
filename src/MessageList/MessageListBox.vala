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
    public GenericArray<string> uids { get; private set; default = new GenericArray<string> (); }

    private Gtk.ListBox list_box;
    private Gtk.ScrolledWindow scrolled_window;

    public MessageListBox () {
        Object (
            orientation: Gtk.Orientation.VERTICAL,
            spacing: 0
        );
    }

    construct {
        var placeholder = new Gtk.Label (_("No Message Selected"));
        placeholder.visible = true;

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

        scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = NEVER
        };
        scrolled_window.add (list_box);
        // Prevent the focus of the webview causing the ScrolledWindow to scroll
        var scrolled_child = scrolled_window.get_child ();
        if (scrolled_child is Gtk.Container) {
            ((Gtk.Container) scrolled_child).set_focus_vadjustment (new Gtk.Adjustment (0, 0, 0, 0, 0, 0));
        }

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

        list_box.get_children ().foreach ((child) => {
            child.destroy ();
        });
        uids = new GenericArray<string> ();

        if (node == null) {
            return;
        }

        /*
         * If there is a node, we can move the thread even without loading all
         * individual messages.
         */
        can_move_thread (true);

        var item = new MessageListItem (node.message);
        list_box.add (item);
        uids.add (node.message.uid);
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
    }

    private void go_down (Camel.FolderThreadNode node) {
        unowned Camel.FolderThreadNode? current_node = node;
        while (current_node != null) {
            var item = new MessageListItem (current_node.message);
            list_box.add (item);
            uids.add (current_node.message.uid);
            if (current_node.next != null) {
                go_down ((Camel.FolderThreadNode?) current_node.next);
            }

            current_node = (Camel.FolderThreadNode?) current_node.child;
        }
    }

    public async void add_inline_composer (ComposerWidget.Type type, MessageListItem? message_item = null) {
        /* Can't open a new composer if thread is empty or currently has a composer open */
        var last_child = list_box.get_row_at_index ((int) list_box.get_children ().length () - 1);
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
            can_reply (true);
            can_move_thread (true);
            list_box.remove (composer);
            composer.destroy ();
        });
        list_box.add (composer);
        can_reply (false);
        can_move_thread (true);
    }

    public void scroll_to_bottom () {
        // Adding the inline composer then trying to scroll to the bottom doesn't work as
        // the scrolled window doesn't resize instantly. So connect a one time signal to
        // scroll to the bottom when the inline composer is added
        var adjustment = scrolled_window.get_vadjustment ();
        ulong changed_id = 0;
        changed_id = adjustment.changed.connect (() => {
            adjustment.set_value (adjustment.get_upper ());
            adjustment.disconnect (changed_id);
        });
    }

    private void can_reply (bool enabled) {
        unowned var main_window = (Gtk.ApplicationWindow) ((Gtk.Application) GLib.Application.get_default ()).active_window;
        ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_FORWARD)).set_enabled (enabled);
        ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_REPLY_ALL)).set_enabled (enabled);
        ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_REPLY)).set_enabled (enabled);
    }

    private void can_move_thread (bool enabled) {
        unowned var main_window = (Gtk.ApplicationWindow) ((Gtk.Application) GLib.Application.get_default ()).active_window;
        ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_ARCHIVE)).set_enabled (enabled);
        ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_MARK)).set_enabled (enabled);
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
