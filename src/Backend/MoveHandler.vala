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
    public enum MoveType {
        TRASH,
        ARCHIVE,
        MOVE
    }

    private const int TIMEOUT_DURATION = 5;

    private Camel.Folder src_folder;
    private Camel.Folder? dst_folder;
    private Gee.ArrayList<weak Camel.MessageInfo> moved_messages;
    private MoveType move_type;

    private uint timeout_id = 0;

    public async int move_messages (Camel.Folder source_folder, MoveType _move_type, Gee.ArrayList<unowned Camel.FolderThreadNode?> threads, Variant? dest_folder = null) throws Error {
        yield expire_undo ();

        src_folder = source_folder;
        move_type = _move_type;

        switch (move_type) {
            case TRASH:
                var store = src_folder.parent_store;
                dst_folder = yield store.get_trash_folder (GLib.Priority.DEFAULT);
                break;
            case MOVE:
                var dest_folder_full_name = dest_folder.get_string ();
                var store = src_folder.parent_store;
                dst_folder = yield store.get_folder (dest_folder_full_name, Camel.StoreGetFolderFlags.NONE, GLib.Priority.DEFAULT, null);
                break;
            case ARCHIVE:
                var archive_folder_uri = get_archive_folder_uri_from_folder (source_folder);
                Camel.Store dest_store;
                string dest_folder_full_name;
                if (!get_folder_from_uri (archive_folder_uri, out dest_store, out dest_folder_full_name)) {
                    return 0;
                }
                dst_folder = yield dest_store.get_folder (dest_folder_full_name, Camel.StoreGetFolderFlags.NONE, GLib.Priority.DEFAULT, null);
                break;
        }

        if (dst_folder == null) {
            return 0;
        }

        moved_messages = new Gee.ArrayList<weak Camel.MessageInfo> ();

        foreach (unowned var thread in threads) {
            collect_thread_messages (thread);
        }

        src_folder.freeze ();

        foreach (var info in moved_messages) {
            info.set_flags (Camel.MessageFlags.DELETED, ~0);
        }

        src_folder.thaw ();

        timeout_id = GLib.Timeout.add_seconds (TIMEOUT_DURATION, () => {
            expire_undo.begin ();
            return Source.REMOVE;
        });

        return moved_messages.size;
    }

    private bool get_folder_from_uri (string uri, out Camel.Store? store, out string? folder_name) throws GLib.Error {
        store = null;
        folder_name = null;

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

    public void undo_last_move () {
        Source.remove (timeout_id);
        timeout_id = 0;

        src_folder.freeze ();

        foreach (var info in moved_messages) {
            info.set_flags (Camel.MessageFlags.DELETED, 0);
        }

        src_folder.thaw ();
    }

    public async void expire_undo () {
        if (timeout_id == 0) {
            return;
        }

        Source.remove (timeout_id);
        timeout_id = 0;

        var message_uids = new GenericArray<string> ();
        foreach (unowned var message in moved_messages) {
            message_uids.add (message.uid);
        }

        dst_folder.freeze ();
        src_folder.freeze ();

        foreach (var info in moved_messages) {
            info.set_flags (Camel.MessageFlags.DELETED, 0);
        }

        try {
            yield src_folder.transfer_messages_to (message_uids, dst_folder, true, GLib.Priority.DEFAULT, null, null);
        } catch (Error e) {
            critical (e.message);
        }

        dst_folder.thaw ();
        src_folder.thaw ();
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
