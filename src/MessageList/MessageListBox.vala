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
    public Gtk.ListBox list_box;
    public Gtk.ScrolledWindow scrolled_window;

    public MessageListBox () {
    }

    construct {
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
        this.append (scrolled_window);

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
        for (int i = 1; current_child != null; i++) {
            list_box.remove (current_child);
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

        // var children = get_children ();
        // var num_children = children.length ();
        // if (num_children > 0) {
        //     var child = get_row_at_index ((int) num_children - 1);
        //     if (child != null && child is MessageListItem) {
        //         var list_item = (MessageListItem) child;
        //         list_item.expanded = true;
        //         list_item.bind_property ("loaded", this, "can-reply", BindingFlags.SYNC_CREATE);
        //     }
        // }
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

    // public async void add_inline_composer (ComposerWidget.Type type, MessageListItem? message_item = null) {
    //     /* Can't open a new composer if thread is empty or currently has a composer open */
    //     var last_child = get_row_at_index ((int) get_children ().length () - 1);
    //     if (last_child == null || last_child is InlineComposer) {
    //         return;
    //     }

    //     if (message_item == null) {
    //         message_item = (MessageListItem) last_child;
    //     }

    //     string content_to_quote = "";
    //     Camel.MimeMessage? mime_message = null;
    //     Camel.MessageInfo? message_info = null;
    //     content_to_quote = yield message_item.get_message_body_html ();
    //     mime_message = message_item.mime_message;
    //     message_info = message_item.message_info;

    //     var composer = new InlineComposer (type, message_info, mime_message, content_to_quote);
    //     composer.discarded.connect (() => {
    //         can_reply = true;
    //         can_move_thread = true;
    //         remove (composer);
    //         composer.destroy ();
    //     });
    //     add (composer);
    //     can_reply = false;
    //     can_move_thread = true;
    // }

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
