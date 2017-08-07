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

    public MessageListBox () {
        Object (selection_mode: Gtk.SelectionMode.NONE);
    }

    construct {
        get_style_context ().add_class ("deck");
    }

    public void set_conversation (Camel.FolderThreadNode node) {
        get_children ().foreach ((child) => {
            child.destroy ();
        });

        var item = new MessageListItem (node.message);
        add (item);
        if (node.child != null) {
            go_down ((Camel.FolderThreadNode?) node.child);
        }

        var children = get_children ();
        if (children.length () == 1) {
            var child = get_row_at_index (0);
            if (child is MessageListItem) {
                ((MessageListItem) child).expanded = true;
            }
        } else {
            var child = get_row_at_index ((int) children.length () - 1);
            if (child != null && child is MessageListItem) {
                ((MessageListItem) child).expanded = true;
            }
        }
    }

    private void go_down (Camel.FolderThreadNode node) {
        unowned Camel.FolderThreadNode? current_node = node;
        while (current_node != null) {
            var item = new MessageListItem (current_node.message);
            add (item);
            if (current_node.next != null) {
                go_down ((Camel.FolderThreadNode?) current_node.next);
            }

            current_node = (Camel.FolderThreadNode?) current_node.child;
        }
    }

    public void reply () {
        var last_child = get_row_at_index ((int) get_children ().length () - 1);
        var is_composer = (last_child != null && last_child is InlineComposer);
        if (!is_composer) {
            add (new InlineComposer ());
        }
    }
}
