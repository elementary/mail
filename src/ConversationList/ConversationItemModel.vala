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
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public class Mail.ConversationItemModel : GLib.Object {
    public Camel.FolderThreadNode node { get; private set; }

    public string formatted_date {
        owned get {
            return Granite.DateTime.get_relative_datetime (new DateTime.from_unix_local (timestamp));
        }
    }

    public uint num_messages {
        get {
            return count_thread_messages (node);
        }
    }

    public string from {
        owned get {
            var from_parts = node.message.from.split ("<");
            return GLib.Markup.escape_text (from_parts[0].strip ());
        }
    }

    public string subject {
        get {
            return node.message.subject;
        }
    }

    public bool flagged {
        get {
            return Camel.MessageFlags.FLAGGED in (int)node.message.flags;
        }
    }

    public bool unread {
        get {
            return !(Camel.MessageFlags.SEEN in (int)node.message.flags);
        }
    }

    public int64 timestamp {
        get {
            int64 time = int64.max (node.message.date_received, node.message.date_sent);
            unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) node.child;
            while (child != null) {
                time = int64.max (time, child.message.date_received);
                time = int64.max (time, child.message.date_sent);
                child = (Camel.FolderThreadNode?) child.next;
            }

            return time;
        }
    }

    public ConversationItemModel (Camel.FolderThreadNode node) {
        update_node (node);
    }

    public void update_node (Camel.FolderThreadNode new_node) {
        node = new_node;
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
