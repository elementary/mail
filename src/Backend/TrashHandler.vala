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

    public async int delete_threads (Backend.Account account, Camel.Folder folder, Gee.ArrayList<Camel.FolderThreadNode?> threads) {
        previous_folder = folder;

        GenericArray<string> uids = new GenericArray<string> ();

        foreach (var thread in threads) {
            add_thread_uids (ref uids, thread);
        }

        try {
            var offline_store = (Camel.OfflineStore) account.service;
            var trash_folder = offline_store.get_trash_folder_sync ();
            if (trash_folder == null) {
                critical ("Could not find trash folder in account " + account.service.display_name);
                return 0;
            }

            trash_folder.freeze ();
            folder.freeze ();
            try {
                yield folder.transfer_messages_to (uids, trash_folder, true, GLib.Priority.DEFAULT, null, out deleted_uids);
            } finally {
                trash_folder.thaw ();
                folder.thaw ();
            }
        } catch (Error e) {
            critical ("Could not move messages to trash: " + e.message);
            return 0;
        }

        return uids.length;
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
