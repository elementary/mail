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

public class Mail.MoveHandler : Object {
    public signal void queue_updated (uint queued_messages);

    public enum MoveType {
        ARCHIVE,
        TRASH,
        VTRASH
    }

    private class MoveOperation {
        public Camel.Folder src_folder;
        public Camel.Folder? dst_folder;
        public MoveType move_type;
        public Gee.ArrayList<weak Camel.MessageInfo> moved_messages;
    }

    private const int TIMEOUT_DURATION = 5;

    private HashTable<uint, MoveOperation> move_operations_by_timeout_id;
    private uint last_move_id = 0;

    construct {
        move_operations_by_timeout_id = new HashTable<uint, MoveOperation> (null, null);
    }

    public async int move_messages (Camel.Folder source_folder, MoveType _move_type, Gee.ArrayList<unowned Camel.FolderThreadNode?> threads, Variant? dest_folder) throws Error {
        var operation = new MoveOperation () {
            src_folder = source_folder,
            dst_folder = null,
            move_type = _move_type
        };

        switch (operation.move_type) {
            case ARCHIVE:
                var archive_folder_uri = get_archive_folder_uri_from_operation (operation);
                Camel.Store dest_store;
                string dest_folder_full_name;
                if (!get_folder_from_uri (archive_folder_uri, out dest_store, out dest_folder_full_name)) {
                    return 0;
                }
                operation.dst_folder = yield dest_store.get_folder (dest_folder_full_name, Camel.StoreGetFolderFlags.NONE, GLib.Priority.DEFAULT, null);
                break;

            case TRASH:
                var store = operation.src_folder.parent_store;
                if (Camel.StoreFlags.VTRASH in ((Camel.StoreFlags)store.get_flags ())) {
                    operation.move_type = VTRASH;
                } else {
                    operation.dst_folder = yield store.get_trash_folder (GLib.Priority.DEFAULT);
                }
                break;

            case VTRASH:
                throw new OptionError.BAD_VALUE ("MoveType.VTRASH: Invalid value"); //TODO: Correct error here?
        }

        if ((operation.dst_folder == null && operation.move_type != VTRASH) || operation.dst_folder == operation.src_folder) {
            return 0;
        }

        operation.moved_messages = new Gee.ArrayList<weak Camel.MessageInfo> ();

        foreach (unowned var thread in threads) {
            collect_thread_messages (operation, thread);
        }

        operation.src_folder.freeze ();

        foreach (var info in operation.moved_messages) {
            info.set_flags (Camel.MessageFlags.DELETED, ~0);
        }

        operation.src_folder.thaw ();

        uint timeout_id = 0;
        timeout_id = GLib.Timeout.add_seconds (TIMEOUT_DURATION, () => {
            expire_undo.begin (timeout_id);
            return Source.REMOVE;
        });

        move_operations_by_timeout_id.set (timeout_id, operation);
        last_move_id = timeout_id;

        queue_updated (move_operations_by_timeout_id.length);

        return operation.moved_messages.size;
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

    private string? get_archive_folder_uri_from_operation (MoveOperation operation) {
        unowned Camel.Store store = (Camel.Store)operation.src_folder.get_parent_store ();

        if (operation.src_folder is Camel.VeeFolder) {
            var vee_folder = (Camel.VeeFolder)operation.src_folder;

            store = null;
            unowned Camel.Folder? orig_folder = null;

            foreach (unowned Camel.MessageInfo message in operation.moved_messages) {
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
        if (last_move_id == 0) {
            return;
        }

        Source.remove (last_move_id);
        var operation = move_operations_by_timeout_id.take (last_move_id);
        last_move_id = 0;

        operation.src_folder.freeze ();

        foreach (var info in operation.moved_messages) {
            info.set_flags (Camel.MessageFlags.DELETED, 0);
        }

        operation.src_folder.thaw ();

        queue_updated (move_operations_by_timeout_id.length);
    }

    public async void expire_undo (uint id) {
        Source.remove (id);

        if (id == last_move_id) {
            last_move_id = 0;
        }

        var operation = move_operations_by_timeout_id.take (id);

        if (operation.move_type == MoveHandler.MoveType.VTRASH) {
            queue_updated (move_operations_by_timeout_id.length);
            return;
        }

        var message_uids = new GenericArray<string> ();
        foreach (unowned var message in operation.moved_messages) {
            message_uids.add (message.uid);
        }

        operation.dst_folder.freeze ();
        operation.src_folder.freeze ();

        foreach (var info in operation.moved_messages) {
            info.set_flags (Camel.MessageFlags.DELETED, 0);
        }

        try {
            yield operation.src_folder.transfer_messages_to (message_uids, operation.dst_folder, true, GLib.Priority.DEFAULT, null, null);
        } catch (Error e) {
            critical (e.message);
        }

        operation.dst_folder.thaw ();
        operation.src_folder.thaw ();

        queue_updated (move_operations_by_timeout_id.length);
    }

    private void collect_thread_messages (MoveOperation operation, Camel.FolderThreadNode thread) {
        operation.moved_messages.add (thread.message);
        unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) thread.child;
        while (child != null) {
            collect_thread_messages (operation, child);
            child = (Camel.FolderThreadNode?) child.next;
        }
    }
}
