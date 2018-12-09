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
    private GenericArray<string> deleted_uids;

    public int delete_threads (Backend.Account account, Camel.Folder folder, Gee.ArrayList<Camel.FolderThreadNode?> threads) {
        previous_folder = folder;

        GenericArray<string> uids = new GenericArray<string> ();

        foreach (var thread in threads) {
            add_thread_uids (ref uids, thread);
        }

        deleted_uids = new GenericArray<string> ();
        for (int i = 0; i < uids.length; i++) {
            deleted_uids.add (uids[i]);
        }

        folder.freeze ();

        for (int i = 0; i < uids.length; i++) {
            folder.set_message_flags (uids[i], Camel.MessageFlags.DELETED, ~0);
        }

        return uids.length;
    }

    public void undo_last_delete () {
        previous_folder.freeze ();

        for (int i = 0; i < deleted_uids.length; i++) {
            warning (deleted_uids[i]);
            warning (previous_folder.get_message_flags (deleted_uids[i]).to_string ());
            previous_folder.set_message_flags (deleted_uids[i], Camel.MessageFlags.DELETED, 0);
        }

        previous_folder.thaw ();
    }

    public void expire_undo () {
        previous_folder.thaw ();
    }

    private void add_thread_uids (ref GenericArray<string> uids, Camel.FolderThreadNode thread) {
        uids.add (thread.message.uid);
        unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) thread.child;
        while (child != null) {
            add_thread_uids (ref uids, child);
            child = (Camel.FolderThreadNode?) child.next;
        }
    }
}
