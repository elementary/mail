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

 errordomain MoveError {
     DST_FOLDER_NOT_FOUND,
     FAILED
 }

public class Mail.MoveOperation : Object {
    public enum MoveType {
        ARCHIVE,
        MOVE,
        TRASH,
        VTRASH
    }

    private const int TIMEOUT_DURATION = 5;

    private static int n_messages_queued = 0;
    private static MoveOperation? last_move_operation;
    private static Gtk.Spinner spinner;

    public static void undo_last_move () {
        if (last_move_operation == null) {
            return;
        }

        Source.remove (last_move_operation.timeout_id);
        update_queue (-last_move_operation.moved_messages.size);
        last_move_operation.undone ();

        last_move_operation = null;
    }

    public static void bind_spinner (Gtk.Spinner _spinner) {
        spinner = _spinner;
    }

    private static void update_queue (int change) {
        n_messages_queued += change;

        if (spinner == null) {
            return;
        }

        if (n_messages_queued == 0) {
            spinner.hide ();
        } else {
            spinner.tooltip_text = _("Moving messages… (%u remaining)").printf (n_messages_queued);
            spinner.show ();
        }
    }

    public signal void undone ();

    private Camel.Folder src_folder;
    private Camel.Folder? dst_folder;
    private MoveType move_type;
    private Gee.ArrayList<weak Camel.MessageInfo> moved_messages;
    private uint timeout_id;

    public async MoveOperation (
        Camel.Folder _src_folder,
        MoveType _move_type,
        Gee.ArrayList<unowned Camel.FolderThreadNode?> threads,
        Variant? dst_folder_full_name,
        out uint n_messages_moved
    ) throws Error {
        src_folder = _src_folder;
        dst_folder = null;
        move_type = _move_type;
        moved_messages = new Gee.ArrayList<weak Camel.MessageInfo> ();

        foreach (unowned var thread in threads) {
            yield collect_thread_messages (thread);
        }

        switch (move_type) {
            case ARCHIVE:
                var archive_folder_uri = get_archive_folder_uri ();
                if (!yield set_dst_folder_for_uri (archive_folder_uri)) {
                    throw new MoveError.DST_FOLDER_NOT_FOUND (_("No Archive folder is configured."));
                }
                break;

            case MOVE:
                unowned var dest_folder_full_name = dest_folder.get_string ();
                var store = src_folder.parent_store;
                dst_folder = yield store.get_folder (dest_folder_full_name, Camel.StoreGetFolderFlags.NONE, GLib.Priority.DEFAULT, null);
                break;

            case TRASH:
                var store = src_folder.parent_store;
                if (Camel.StoreFlags.VTRASH in ((Camel.StoreFlags)store.get_flags ())) {
                    move_type = VTRASH;
                } else {
                    dst_folder = yield store.get_trash_folder (GLib.Priority.DEFAULT);
                }
                break;

            case VTRASH:
                throw new OptionError.BAD_VALUE ("MoveType.VTRASH: Invalid value");
        }

        if (dst_folder == null && move_type != VTRASH) {
            throw new MoveError.DST_FOLDER_NOT_FOUND (_("The destination folder was not found."));
        }

        if (src_folder == dst_folder) {
            throw new MoveError.DST_FOLDER_NOT_FOUND (_("The source folder is the destination folder."));
        }

        timeout_id = GLib.Timeout.add_seconds (TIMEOUT_DURATION, () => {
            finish.begin ((obj, res) => {
                try {
                    finish.end (res);
                } catch (Error e) {
                    warning ("Failed to finish move operation: %s", e.message);
                }
            });
            return Source.REMOVE;
        });

        last_move_operation = this;
        update_queue (moved_messages.size);

        n_messages_moved = moved_messages.size;
    }

    private async bool set_dst_folder_for_uri (string uri) throws GLib.Error {
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
            dst_folder = yield ((Camel.Store)service).get_folder (parsed_folder_name, Camel.StoreGetFolderFlags.NONE, GLib.Priority.DEFAULT, null);
            return true;
        }

        return false;
    }

    private string? get_archive_folder_uri () {
        unowned Camel.Store store = (Camel.Store)src_folder.get_parent_store ();

        if (src_folder is Camel.VeeFolder) {
            var vee_folder = (Camel.VeeFolder)src_folder;

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

    private async void collect_thread_messages (Camel.FolderThreadNode thread) {
        moved_messages.add (thread.message);
        unowned Camel.FolderThreadNode? child = (Camel.FolderThreadNode?) thread.child;
        while (child != null) {
            yield collect_thread_messages (child);
            child = (Camel.FolderThreadNode?) child.next;
        }
    }

    private async void finish () throws Error {
        if (this == last_move_operation) {
            last_move_operation = null;
        }

        if (move_type == VTRASH) {
            foreach (unowned var message in moved_messages) {
                message.set_flags (Camel.MessageFlags.DELETED, ~0);
            }
            update_queue (-moved_messages.size);
            return;
        }

        if (move_type == VTRASH) {
            return;
        }

        var message_uids = new GenericArray<string> ();
        foreach (unowned var message in moved_messages) {
            message_uids.add (message.uid);
        }

        src_folder.freeze ();
        dst_folder.freeze ();

        if (!yield src_folder.transfer_messages_to (message_uids, dst_folder, true, GLib.Priority.DEFAULT, null, null)) {
            throw new MoveError.FAILED ("Failed to move messages");
        }

        src_folder.thaw ();
        dst_folder.thaw ();

        update_queue (-moved_messages.size);
    }
}
