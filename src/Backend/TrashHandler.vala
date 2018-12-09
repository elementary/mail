// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2018 elementary LLC. (https://elementary.io)
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
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public class Mail.TrashHandler {
    private Camel.Folder previous_folder;
    private Gee.ArrayList<weak Camel.MessageInfo> deleted_messages;
    private bool frozen = false;
    private uint timeout_id = -1;

    public int delete_threads (Camel.Folder folder, Gee.ArrayList<Camel.FolderThreadNode?> threads) {
        previous_folder = folder;

        deleted_messages = new Gee.ArrayList<weak Camel.MessageInfo> ();

        foreach (var thread in threads) {
            collect_thread_messages (thread);
        }

        folder.freeze ();
        frozen = true;

        timeout_id = Timeout.add_seconds (10, () => {
            expire_undo ();
            timeout_id = -1;
            return Source.REMOVE;
        });

        foreach (var info in deleted_messages) {
            info.set_flags (Camel.MessageFlags.DELETED, ~0);
        }

        return deleted_messages.size;
    }

    public void undo_last_delete () {
        foreach (var info in deleted_messages) {
            info.set_flags (Camel.MessageFlags.DELETED, 0);
        }
    }

    public void expire_undo () {
        if (timeout_id != -1) {
            Source.remove (timeout_id);
            timeout_id = -1;
        }

        if (frozen) {
            frozen = false;
            previous_folder.thaw ();
        }
    }

    private void collect_thread_messages (Camel.FolderThreadNode thread) {
        deleted_messages.add (thread.message);
        unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) thread.child;
        while (child != null) {
            collect_thread_messages (child);
            child = (Camel.FolderThreadNode?) child.next;
        }
    }
}
