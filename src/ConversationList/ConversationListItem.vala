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

public class Mail.ConversationListItem : VirtualizingListBoxRow {
    private Gtk.Image status_icon;
    private Gtk.Label date;
    private Gtk.Label messages;
    private Gtk.Label source;
    private Gtk.Label topic;
    private Gtk.Revealer flagged_icon_revealer;
    private Gtk.Revealer status_revealer;

    construct {
        status_icon = new Gtk.Image.from_icon_name ("mail-unread-symbolic", Gtk.IconSize.MENU);

        status_revealer = new Gtk.Revealer ();
        status_revealer.add (status_icon);

        var flagged_icon = new Gtk.Image.from_icon_name ("starred-symbolic", Gtk.IconSize.MENU);
        flagged_icon_revealer = new Gtk.Revealer ();
        flagged_icon_revealer.add (flagged_icon);

        source = new Gtk.Label (null);
        source.hexpand = true;
        source.ellipsize = Pango.EllipsizeMode.END;
        source.use_markup = true;
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
        grid.attach (status_revealer, 0, 0);
        grid.attach (flagged_icon_revealer, 0, 1, 1, 1);
        grid.attach (source, 1, 0, 1, 1);
        grid.attach (date, 2, 0, 2, 1);
        grid.attach (topic, 1, 1, 2, 1);
        grid.attach (messages, 3, 1, 1, 1);

        get_style_context ().add_class ("conversation-list-item");
        add (grid);

        show_all ();
    }

    public void assign (ConversationItemModel data) {
        date.label = data.formatted_date;
        topic.label = data.subject;
        source.label = data.from;

        messages.label = data.num_messages > 1 ? "%u".printf (data.num_messages) : null;
        messages.visible = data.num_messages > 1;
        messages.no_show_all = data.num_messages <= 1;

        if (data.unread) {
            get_style_context ().add_class ("unread-message");

            status_icon.icon_name = "mail-unread-symbolic";
            status_icon.tooltip_text = _("Unread");
            status_icon.get_style_context ().add_class ("attention");

            status_revealer.reveal_child = true;
        } else {
            get_style_context ().remove_class ("unread-message");
            status_icon.get_style_context ().remove_class ("attention");

            if (data.replied_all || data.replied) {
                status_icon.icon_name = "mail-replied-symbolic";
                status_icon.tooltip_text = _("Replied");
                status_revealer.reveal_child = true;
            } else if (data.forwarded) {
                status_icon.icon_name = "go-next-symbolic";
                status_icon.tooltip_text = _("Forwarded");
                status_revealer.reveal_child = true;
            } else {
                status_revealer.reveal_child = false;
            }
        }

        flagged_icon_revealer.reveal_child = data.flagged;
    }

    private static int64 get_newest_timestamp (Camel.FolderThreadNode node, int64 highest = -1) {
        int64 time = highest;
        time = int64.max (time, node.message.date_received);
        time = int64.max (time, node.message.date_sent);

        unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) node.child;
        while (child != null) {
            time = get_newest_timestamp (child, time);
            child = (Camel.FolderThreadNode?) child.next;
        }

        return time;
    }
}
