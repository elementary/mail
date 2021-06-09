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
    public string service_uid { get; construct; }
    public Camel.FolderThreadNode? node;

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
            string[] senders = {};

            unowned Camel.FolderThreadNode? current_node = node;
            while (current_node != null) {
                weak Camel.MessageInfo? message = current_node.message;
                if (message != null) {
                    var address = new Camel.InternetAddress ();
                    if (address.decode (message.from) > 0) {
                        unowned string? ia_name;
                        unowned string? ia_address;

                        string sender;
                        address.get (0, out ia_name, out ia_address);
                        if (ia_name != null && ia_name != "") {
                            sender = ia_name;
                        } else {
                            sender = ia_address;
                        }

                        if (!(sender in senders)) {
                            senders += sender;
                        }
                    }
                }

                current_node = (Camel.FolderThreadNode?) current_node.child;
            }

            if (senders.length > 0) {
                return string.joinv (_(", "), senders);
            }

            return _("Unknown");
        }
    }

    public string subject {
        get {
            weak Camel.MessageInfo? message = node.message;
            if (message == null) {
                return _("Unknown");
            }

            return message.subject;
        }
    }

    public bool flagged {
        get {
            weak Camel.MessageInfo? message = node.message;
            if (message == null) {
                return false;
            }

            return Camel.MessageFlags.FLAGGED in (int)message.flags;
        }
    }

    public bool forwarded {
        get {
            weak Camel.MessageInfo? message = node.message;
            if (message == null) {
                return false;
            }

            return Camel.MessageFlags.FORWARDED in (int)message.flags;
        }
    }

    public bool replied {
        get {
            weak Camel.MessageInfo? message = node.message;
            if (message == null) {
                return false;
            }

            return Camel.MessageFlags.ANSWERED in (int)message.flags;
        }
    }

    public bool replied_all {
        get {
            weak Camel.MessageInfo? message = node.message;
            if (message == null) {
                return false;
            }

            return Camel.MessageFlags.ANSWERED_ALL in (int)message.flags;
        }
    }

    public bool unread {
        get {
            weak Camel.MessageInfo? message = node.message;
            if (message == null) {
                return false;
            }

            return !(Camel.MessageFlags.SEEN in (int)message.flags);
        }
    }

    public bool deleted {
        get {
            weak Camel.MessageInfo? message = node.message;
            if (message == null) {
                return false;
            }

            return Camel.MessageFlags.DELETED in (int)message.flags;
        }
    }

    public int64 timestamp {
        get {
            return get_newest_timestamp (node);
        }
    }

    public ConversationItemModel (Camel.FolderThreadNode node, string service_uid) {
        Object (service_uid: service_uid);
        update_node (node);
    }

    public void update_node (Camel.FolderThreadNode new_node) {
        node = new_node;
    }

    private static uint count_thread_messages (Camel.FolderThreadNode node) {
        uint i = 1;
        for (unowned Camel.FolderThreadNode? child = node.child; child != null; child = child.next) {
            i += count_thread_messages (child);
        }

        return i;
    }

    private static int64 get_newest_timestamp (Camel.FolderThreadNode node, int64 highest = -1) {
        int64 time = highest;
        weak Camel.MessageInfo? message = node.message;
        if (message != null) {
            time = int64.max (time, message.date_received);
            time = int64.max (time, message.date_sent);
        }

        for (unowned Camel.FolderThreadNode? child = node.child; child != null; child = child.next) {
            time = get_newest_timestamp (child, time);
        }

        return time;
    }
}
