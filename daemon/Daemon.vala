/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public class Mail.Daemon : GLib.Application {

    private NetworkMonitor network_monitor;
    private Camel.Session session;
    private HashTable<E.Source, Camel.Folder> inbox_folders;
    private HashTable<E.Source, uint> synchronize_timeout_ids;
    private E.SourceRegistry registry;

    construct {
        inbox_folders = new HashTable<E.Source, Camel.Folder> (E.Source.hash, E.Source.equal);
        synchronize_timeout_ids = new HashTable<E.Source, uint> (E.Source.hash, E.Source.equal);
    }

    private async void start () {
        network_monitor = GLib.NetworkMonitor.get_default ();

        try {
            registry = yield new E.SourceRegistry (null);
            session = new CamelSession (registry);

        } catch (Error e) {
            critical ("Error starting daemon: %s", e.message);
            return;
        }

        var sources = registry.list_sources (E.SOURCE_EXTENSION_MAIL_ACCOUNT);
        foreach (var source in sources) {
            add_source (source);
        }

        registry.source_added.connect (add_source);
        registry.source_removed.connect (remove_source);

        registry.source_changed.connect ((source) => {
            remove_source (source);
            add_source (source);
        });
    }

    private void add_source (E.Source source) {
        if (!source.has_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT)) {
            return;
        }
        unowned string uid = source.get_uid ();
        unowned string display_name = source.get_display_name ();

        if (uid == "vfolder") {
            debug ("[%s] Is a vfolder. Ignoring it…", display_name);
            return;
        }

        unowned var extension = (E.SourceMailAccount) source.get_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT);
        if (extension.backend_name == "mbox") {
            debug ("[%s] Is a local inbox. Ignoring it…", display_name);
            return;
        }

        Camel.Store? store = null;
        try {
            store = (Camel.Store) session.add_service (uid, extension.backend_name, Camel.ProviderType.STORE);
        } catch (Error e) {
            warning ("[%s] Error adding service: %s", display_name, e.message);
        }

        if (store != null) {
            try {
                var inbox_folder = store.get_inbox_folder_sync (null);

                if (inbox_folder != null) {
                    inbox_folder.changed.connect ((change_info) => {
                        inbox_folder_changed (source, change_info);
                    });
                    inbox_folders.insert (source, inbox_folder);

                    debug ("[%s] Watching inbox for new messages…", display_name);
                    var refresh_timeout_id = GLib.Timeout.add_seconds (10, () => {
                        inbox_folder_synchronize_sync.begin (source);
                        return GLib.Source.CONTINUE;
                    });
                    synchronize_timeout_ids.insert (source, refresh_timeout_id);

                    inbox_folder_synchronize_sync.begin (source);

                } else {
                    debug ("[%s] Inbox folder not found. Can't watch for new messages.", display_name);
                }

            } catch (Error e) {
                warning ("[%s] Error getting inbox folder: %s", display_name, e.message);
            }

        } else {
            debug ("[%s] No store available.", display_name);
        }
    }

    private void remove_source (E.Source source) {
        if (!source.has_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT)) {
            return;
        }
        debug ("[%s] Removing…", source.display_name);

        bool timeout_id_exists;
        var timeout_id = synchronize_timeout_ids.take (source, out timeout_id_exists);
        if (timeout_id_exists) {
            GLib.Source.remove (timeout_id);
        }

        bool exists;
        var inbox_folder = inbox_folders.take (source, out exists);
        if (exists) {
            session.remove_service (inbox_folder.parent_store);
        }
    }

    private async void inbox_folder_synchronize_sync (E.Source source) {
        if (!network_monitor.network_available) {
            debug ("[%s] Network is not avaible. Skipping…", source.display_name);
            return;
        }

        var inbox_folder = inbox_folders.get (source);
        if (inbox_folder != null && inbox_folder.parent_store is Camel.OfflineStore) {
            debug ("[%s] Synchronizing…", source.display_name);

            var offline_store = (Camel.OfflineStore) inbox_folder.parent_store;
            try {
                offline_store.set_online_sync (true, null);
                offline_store.connect_sync (null);
                offline_store.synchronize_sync (false, null);
                inbox_folder.synchronize_sync (false, null);
                inbox_folder.refresh_info_sync (null);

            } catch (Error e) {
                warning ("[%s] Error synchronizing: %s", source.display_name, e.message);
            }
        }
    }

    private void inbox_folder_changed (E.Source source, Camel.FolderChangeInfo changes) {
        warning ("....... INBOX FOLDER CHANGED .................");
        var inbox_folder = inbox_folders.get (source);
        if (inbox_folder == null) {
            return;
        }

        unowned var added_uids = changes.get_added_uids ();
        if (added_uids != null) {
            added_uids.foreach ((added_uid) => {
                var message_info = inbox_folder.get_message_info (added_uid);
                if (!(Camel.MessageFlags.SEEN in message_info.flags)) {
                    debug ("[%s] New message received. Sending notification %s…", source.display_name, added_uid);

                    var notification = new GLib.Notification (source.display_name);
                    notification.set_body (message_info.subject);
                    send_notification (added_uid, notification);
                }
            });
        }
    }

    protected override void activate () {
        start.begin ();
        Gtk.main ();
    }
}

namespace Mail {
    private static bool has_debug;

    const OptionEntry[] OPTIONS = {
        { "debug", 'd', 0, OptionArg.NONE, out has_debug, N_("Print debug information"), null },
        { null }
    };

    public static int main (string[] args) {
        OptionContext context = new OptionContext ("");
        context.add_main_entries (OPTIONS, null);

        try {
            context.parse (ref args);
        } catch (OptionError e) {
            error (e.message);
        }

        Granite.Services.Logger.initialize ("Mail");
        Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.WARN;

        if (has_debug) {
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;
        }

        var app = new Daemon ();
        return app.run (args);
    }
}