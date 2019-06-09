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
    public Camel.FolderThreadNode? node { get; private set; }
    public int folder_type {get; private set;}

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
            var header_address = Camel.HeaderAddress.decode (node.message.from, null);
            if (header_address.name != null && header_address.name != "") {
                return header_address.name;
            } else {
                return header_address.v_addr;
            }
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

    public bool forwarded {
        get {
            return Camel.MessageFlags.FORWARDED in (int)node.message.flags;
        }
    }

    public bool replied {
        get {
            return Camel.MessageFlags.ANSWERED in (int)node.message.flags;
        }
    }

    public bool replied_all {
        get {
            return Camel.MessageFlags.ANSWERED_ALL in (int)node.message.flags;
        }
    }

    public bool unread {
        get {
            return !(Camel.MessageFlags.SEEN in (int)node.message.flags);
        }
    }

    public bool deleted {
        get {
            return Camel.MessageFlags.DELETED in (int)node.message.flags;
        }
    }

    public int64 timestamp {
        get {
            return get_newest_timestamp (node);
        }
    }

    public ConversationItemModel (Camel.FolderThreadNode node, int folder_type) {
        update_node (node);
        this.folder_type = folder_type;
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

    private static int64 get_newest_timestamp (Camel.FolderThreadNode node, int64 highest = -1) {
        int64 time = highest;
        weak Camel.MessageInfo message = node.message;
        if (message != null) {
            time = int64.max (time, message.date_received);
            time = int64.max (time, message.date_sent);
        }

        unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) node.child;
        while (child != null) {
            time = get_newest_timestamp (child, time);
            child = (Camel.FolderThreadNode?) child.next;
        }

        return time;
    }
}
