/*-
 * Copyright 2018-2019 elementary, Inc. (https://elementary.io)
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

public class Mail.MoveHandler {
    private enum MoveType {
        TRASH,
        ARCHIVE
    }

    private Camel.Folder previous_folder;
    private Camel.Folder? archive_folder;
    private Gee.ArrayList<weak Camel.MessageInfo> moved_messages;
    private bool frozen = false;
    private uint timeout_id = 0;
    private MoveType move_type;

    public int delete_threads (Camel.Folder folder, Gee.ArrayList<Camel.FolderThreadNode?> threads) {
        previous_folder = folder;
        move_type = MoveType.TRASH;

        moved_messages = new Gee.ArrayList<weak Camel.MessageInfo> ();

        foreach (var thread in threads) {
            collect_thread_messages (thread);
        }

        folder.freeze ();
        frozen = true;

        timeout_id = Timeout.add_seconds (10, () => {
            expire_undo ();
            timeout_id = 0;
            return Source.REMOVE;
        });

        foreach (var info in moved_messages) {
            info.set_flags (Camel.MessageFlags.DELETED, ~0);
        }

        return moved_messages.size;
    }

    public async int archive_threads (Camel.Folder folder, Gee.ArrayList<Camel.FolderThreadNode?> threads) {
        previous_folder = folder;
        move_type = MoveType.ARCHIVE;

        moved_messages = new Gee.ArrayList<weak Camel.MessageInfo> ();

        foreach (var thread in threads) {
            collect_thread_messages (thread);
        }

        var archive_folder_uri = get_archive_folder_uri_from_folder (folder);
        Camel.Store dest_store;
        string dest_folder_name;
        if (!get_folder_from_uri (archive_folder_uri, out dest_store, out dest_folder_name)) {
            return 0;
        }

        Camel.Folder? dest_folder = null;
        try {
            dest_folder = yield dest_store.get_folder (dest_folder_name, Camel.StoreGetFolderFlags.NONE, Priority.DEFAULT, null);
        } catch (Error e) {
            warning ("Unable to get destination folder for archive: %s", e.message);
            return 0;
        }

        if (dest_folder == null) {
            return 0;
        }

        var uids = new GenericArray<string> ();
        foreach (var info in moved_messages) {
            uids.add (info.uid);
        }

        archive_folder = dest_folder;
        archive_folder.freeze ();

        folder.freeze ();
        frozen = true;

        GenericArray<string>? transferred_uids;
        if (folder.transfer_messages_to_sync (uids, dest_folder, true, out transferred_uids, null)) {
            if (transferred_uids != null) {
                // TODO: Figure out why uids aren't being returned here
                warning (transferred_uids.length.to_string ());
            } else {
                warning ("Undo not possible: transferred_uids is null.");
            }

            timeout_id = Timeout.add_seconds (10, () => {
                expire_undo ();
                timeout_id = 0;
                return Source.REMOVE;
            });

            return moved_messages.size;
        }

        return 0;
    }

    private bool get_folder_from_uri (string uri, out Camel.Store store, out string folder_name) throws GLib.Error {
        Camel.URL? url = null;
        url = new Camel.URL (uri);
        if (url == null) {
            return false;
        }

        Camel.Service? service = null;
        string? parsed_folder_name = null;

        if (url.protocol == "folder") {
            if (url.host != null) {
                string uid;
                if (url.user == null || url.user == "") {
                    uid = url.host;
                } else {
                    uid = url.user + "@" + url.host;
                }

                service = Backend.Session.get_default ().ref_service (uid);
            }

            if (url.path != null && url.path.has_prefix ("/")) {
                parsed_folder_name = Camel.URL.decode_path (url.path.substring (1));
            }
        }

        if (service != null && service is Camel.Store && parsed_folder_name != null) {
            store = (Camel.Store)service;
            folder_name = parsed_folder_name;
            return true;
        }

        return false;
    }

    private string? get_archive_folder_uri_from_folder (Camel.Folder folder) {
        unowned Camel.Store store = (Camel.Store)folder.get_parent_store ();

        if (folder is Camel.VeeFolder) {
            var vee_folder = (Camel.VeeFolder)folder;

            store = null;
            unowned Camel.Folder? orig_folder = null;

            foreach (unowned Camel.MessageInfo message in moved_messages) {
                orig_folder = vee_folder.get_vee_uid_folder (message.uid);
                if (orig_folder != null) {
                    if (store != null && orig_folder.get_parent_store () != store) {
                        // Don't know which archive folder to use when messages are from
                        // multiple accounts/stores
                        store = null;
                        break;
                    }

                    store = (Camel.Store)orig_folder.get_parent_store ();
                }
            }
        }

        if (store != null) {
            return Backend.Session.get_default ().get_archive_folder_uri_for_service (store);
        }

        return null;
    }

    public async void undo_last_move () {
        if (move_type == MoveType.TRASH) {
            foreach (var info in moved_messages) {
                info.set_flags (Camel.MessageFlags.DELETED, 0);
            }
        } else if (move_type == MoveType.ARCHIVE) {
            var uids = new GenericArray<string> ();
            foreach (var info in moved_messages) {
                uids.add (info.uid);
            }

            yield archive_folder.transfer_messages_to (uids, previous_folder, true, Priority.DEFAULT, null, null);
        }
    }

    public void expire_undo () {
        if (timeout_id != 0) {
            Source.remove (timeout_id);
            timeout_id = 0;
        }

        if (frozen) {
            frozen = false;
            previous_folder.thaw ();

            if (archive_folder != null && archive_folder.is_frozen ()) {
                archive_folder.thaw ();
            }
        }
    }

    private void collect_thread_messages (Camel.FolderThreadNode thread) {
        moved_messages.add (thread.message);
        unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) thread.child;
        while (child != null) {
            collect_thread_messages (child);
            child = (Camel.FolderThreadNode?) child.next;
        }
    }
}
