// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2018 elementary LLC. (https://elementary.io)
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
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public class Mail.ConversationItemModel : Object {
    public Camel.FolderThreadNode node { get; private set; }

    public ConversationItemModel (Camel.FolderThreadNode node) {
        update_node (node);
    }

    public int64 timestamp { get; private set; }
    public uint num_messages { get; private set; }
    public string topic { get; private set; }
    public string from { get; private set; }
    public bool unread { get; set; }
    public bool flagged { get; set; }
    public string formatted_date { get; set; }

    public void update_node (Camel.FolderThreadNode new_node) {
        this.node = new_node;

        if (node.message.date_received == 0) {
            // Sent messages do not have a date_received timestamp.
            timestamp = node.message.date_sent;
        } else {
            timestamp = node.message.date_received;
        }

        num_messages = count_thread_messages (node);
        topic = node.message.subject;

        var from_parts = node.message.from.split ("<");
        from = GLib.Markup.escape_text (from_parts[0].strip ());

        unread = !(Camel.MessageFlags.SEEN in (int)node.message.flags);
        flagged = Camel.MessageFlags.FLAGGED in (int)node.message.flags;
        formatted_date = Granite.DateTime.get_relative_datetime (new DateTime.from_unix_local (timestamp));
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

