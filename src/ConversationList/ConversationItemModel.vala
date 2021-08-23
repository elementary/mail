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

    private Camel.FolderThreadNode? _node;
    public Camel.FolderThreadNode? node {
        get { return _node; }
        set {
            lock (_node) {
                _node = value;
            }
        }
    }

    public string formatted_date {
        owned get {
            return Granite.DateTime.get_relative_datetime (new DateTime.from_unix_local (timestamp));
        }
    }

    public uint num_messages {
        get {
            uint count = 0;

            lock (node) {
                if (node != null) {
                    count = count_thread_messages (node);
                }
            }
            return count;
        }
    }

    public string from {
        owned get {
            string[] senders = {};

            lock (node) {
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
            }

            if (senders.length > 0) {
                return string.joinv (_(", "), senders);
            }

            return _("Unknown");
        }
    }

    public string subject {
        owned get {
            string subject = "";

            lock (node) {
                if (node == null || node.message == null) {
                    subject = _("Unknown");
                } else {
                    subject = node.message.subject;
                }
            }
            return subject;
        }
    }

    public bool flagged {
        get {
            bool flagged = false;

            lock (node) {
                if (node != null && node.message != null) {
                    flagged = Camel.MessageFlags.FLAGGED in (int)node.message.flags;
                }
            }
            return flagged;
        }
    }

    public bool forwarded {
        get {
            bool forwarded = false;

            lock (node) {
                if (node != null && node.message != null) {
                    forwarded = Camel.MessageFlags.FORWARDED in (int)node.message.flags;
                }
            }
            return forwarded;
        }
    }

    public bool replied {
        get {
            bool replied = false;

            lock (node) {
                if (node != null && node.message != null) {
                    replied = Camel.MessageFlags.ANSWERED in (int)node.message.flags;
                }
            }
            return replied;
        }
    }

    public bool replied_all {
        get {
            bool replied_all = false;

            lock (node) {
                if (node != null && node.message != null) {
                    replied_all = Camel.MessageFlags.ANSWERED_ALL in (int)node.message.flags;
                }
            }
            return replied_all;
        }
    }

    public bool unread {
        get {
            var unread = false;

            lock (node) {
                if (node != null && node.message == null) {
                    unread = !(Camel.MessageFlags.SEEN in (int)node.message.flags);
                }
            }
            return unread;
        }
    }

    public bool deleted {
        get {
            var deleted = false;

            lock (node) {
                if (node != null && node.message == null) {
                    deleted = Camel.MessageFlags.DELETED in (int)node.message.flags;
                }
            }
            return deleted;;
        }
    }

    public int64 timestamp {
        get {
            int64 timestamp = -1;

            lock (node) {
                timestamp = get_newest_timestamp (node);
            }
            return timestamp;
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

    private static int64 get_newest_timestamp (Camel.FolderThreadNode? node, int64 highest = -1) {
        int64 time = highest;
        if (node == null) {
            return time;
        }

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
