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

public class Mail.MessageListBox : Gtk.ListBox {
    public signal void hovering_over_link (string? label, string? uri);
    public bool can_reply { get; set; default = false; }
    public bool can_move_thread { get; set; default = false; }
    public GenericArray<string> uids { get; private set; default = new GenericArray<string> (); }

    public MessageListBox () {
        Object (selection_mode: Gtk.SelectionMode.NONE);
    }

    construct {
        var placeholder = new Gtk.Label (_("No Message Selected"));
        placeholder.visible = true;

        var placeholder_style_context = placeholder.get_style_context ();
        placeholder_style_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
        placeholder_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        get_style_context ().add_class ("deck");
        set_placeholder (placeholder);
    }

    public void set_conversation (Camel.FolderThreadNode? node) {
        /*
         * Prevent the user from interacting with the message thread while it
         * is being reloaded. can_reply will be set to true after loading the
         * thread.
         */
        can_reply = false;
        can_move_thread = false;

        get_children ().foreach ((child) => {
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
        can_move_thread = true;

        var item = new MessageListItem (node.message);
        add (item);
        uids.add (node.message.uid);
        if (node.child != null) {
            go_down ((Camel.FolderThreadNode?) node.child);
        }

        var children = get_children ();
        var num_children = children.length ();
        if (num_children > 0) {
            var child = get_row_at_index ((int) num_children - 1);
            if (child != null && child is MessageListItem) {
                var list_item = (MessageListItem) child;
                list_item.expanded = true;
                list_item.bind_property ("loaded", this, "can-reply", BindingFlags.SYNC_CREATE);
            }
        }
    }

    private void go_down (Camel.FolderThreadNode node) {
        unowned Camel.FolderThreadNode? current_node = node;
        while (current_node != null) {
            var item = new MessageListItem (current_node.message);
            add (item);
            uids.add (current_node.message.uid);
            if (current_node.next != null) {
                go_down ((Camel.FolderThreadNode?) current_node.next);
            }

            current_node = (Camel.FolderThreadNode?) current_node.child;
        }
    }

    public async void add_inline_composer (ComposerWidget.Type type, MessageListItem? message_item = null) {
        var children = get_children ();

        /* Can't open a new composer if thread is empty or currently has a composer open */
        var last_child = get_row_at_index ((int) children.length () - 1);
        if (last_child == null || last_child is InlineComposer) {
            return;
        }

        foreach (var child in children) {
            child.hide ();
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
            remove (composer);
            composer.destroy ();

            foreach (var child in get_children ()) {
                child.show ();
            }
        });
        add (composer);
        can_reply = false;
        can_move_thread = true;
    }
}
