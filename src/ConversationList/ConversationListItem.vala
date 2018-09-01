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

public class Mail.ConversationListItem : Gtk.ListBoxRow {
    private Gtk.Label date;
    private Gtk.Label messages;
    private Gtk.Label source;
    private Gtk.Label topic;
    private Gtk.Revealer flagged_icon_revealer;
    private Gtk.Revealer unread_icon_revealer;

    public Camel.FolderThreadNode node { get; private set; }

    public int64 timestamp {
        get {
            int64 timestamp = 0;
            if (node.message.date_received == 0) {
                // Sent messages do not have a date_received timestamp.
                timestamp = node.message.date_sent;

                unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) node.child;
                while (child != null) {
                    if (child.message.date_sent > timestamp) {
                        timestamp = child.message.date_sent;
                    }

                    child = (Camel.FolderThreadNode?) child.next;
                }

                return timestamp;
            }

            timestamp = node.message.date_received;
            unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) node.child;
            while (child != null) {
                if (child.message.date_received > timestamp) {
                    timestamp = child.message.date_received;
                }

                child = (Camel.FolderThreadNode?) child.next;
            }

            return timestamp;
        }
    }

    public ConversationListItem (Camel.FolderThreadNode node) {
        update_node (node);
    }

    construct {
        var unread_icon = new Gtk.Image.from_icon_name ("mail-unread-symbolic", Gtk.IconSize.MENU);
        unread_icon.get_style_context ().add_class ("attention");
        unread_icon_revealer = new Gtk.Revealer ();
        unread_icon_revealer.add (unread_icon);

        var flagged_icon = new Gtk.Image.from_icon_name ("starred-symbolic", Gtk.IconSize.MENU);
        flagged_icon_revealer = new Gtk.Revealer ();
        flagged_icon_revealer.add (flagged_icon);

        source = new Gtk.Label (null);
        source.hexpand = true;
        source.ellipsize = Pango.EllipsizeMode.END;
        source.xalign = 0;
        source.get_style_context ().add_class ("h3");

        messages = new Gtk.Label (null);
        messages.halign = Gtk.Align.END;

        var messages_style = messages.get_style_context ();
        messages_style.add_class (Granite.STYLE_CLASS_BADGE);
        messages_style.add_class (Granite.STYLE_CLASS_SOURCE_LIST);

        topic = new Gtk.Label (null);
        topic.hexpand = true;
        topic.ellipsize = Pango.EllipsizeMode.END;
        topic.xalign = 0;

        date = new Gtk.Label (null);
        date.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var grid = new Gtk.Grid ();
        grid.margin = 12;
        grid.column_spacing = 12;
        grid.row_spacing = 6;
        grid.attach (unread_icon_revealer, 0, 0, 1, 1);
        grid.attach (flagged_icon_revealer, 0, 1, 1, 1);
        grid.attach (source, 1, 0, 1, 1);
        grid.attach (date, 2, 0, 2, 1);
        grid.attach (topic, 1, 1, 2, 1);
        grid.attach (messages, 3, 1, 1, 1);

        get_style_context ().add_class ("conversation-list-item");
        add (grid);

        show_all ();
    }

    public void update_node (Camel.FolderThreadNode node) {
        this.node = node;
        var num_messages = count_thread_messages (node);

        messages.label = num_messages > 1 ? "%u".printf(num_messages) : null;
        messages.no_show_all = num_messages <= 1;
        messages.visible = num_messages > 1;

        topic.label = node.message.subject;

        var from_parts = node.message.from.split ("<");
        var from_name = GLib.Markup.escape_text (from_parts[0].strip ());

        source.label = from_name;

        if (!(Camel.MessageFlags.SEEN in (int)node.message.flags)) {
            get_style_context ().add_class ("unread-message");
            unread_icon_revealer.reveal_child = true;
        } else {
            get_style_context ().remove_class ("unread-message");
        }

        if (Camel.MessageFlags.FLAGGED in (int)node.message.flags) {
            flagged_icon_revealer.reveal_child = true;
        }

        date.label = Granite.DateTime.get_relative_datetime (new DateTime.from_unix_local (timestamp));
    }

    private static uint count_thread_messages (Camel.FolderThreadNode node) {
        unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) node.child;
        uint i = 1;
        while (child != null) {
            i += count_thread_messages (child);
            child = (Camel.FolderThreadNode?) child.next;
        }

        return i;
    }
}
