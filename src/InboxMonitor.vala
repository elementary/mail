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

public class Mail.InboxMonitor : GLib.Object {

    private NetworkMonitor network_monitor;
    private Mail.Backend.Session session;
    private HashTable<Mail.Backend.Account, Camel.Folder> inbox_folders;
    private HashTable<Mail.Backend.Account, uint> synchronize_timeout_ids;

    construct {
        inbox_folders = new HashTable<Mail.Backend.Account, Camel.Folder> (Mail.Backend.Account.hash, Mail.Backend.Account.equal);
        synchronize_timeout_ids = new HashTable<Mail.Backend.Account, uint> (Mail.Backend.Account.hash, Mail.Backend.Account.equal);

        network_monitor = GLib.NetworkMonitor.get_default ();
        session = new Mail.Backend.Session ();
    }

    public async void start () {
        yield session.start ();

        session.get_accounts ().foreach ((account) => {
            add_account (account);
            return true;
        });

        session.account_added.connect (add_account);
        session.account_removed.connect (remove_account);
    }

    private void remove_account () {
        var accounts = session.get_accounts ();

        foreach (var account in inbox_folders.get_keys ()) {
            if (!accounts.contains (account)) {
                lock (inbox_folders) {
                    inbox_folders.remove (account);
                }

                lock (synchronize_timeout_ids) {
                    if (synchronize_timeout_ids.contains (account)) {
                        GLib.Source.remove (synchronize_timeout_ids.get (account));
                    }

                    synchronize_timeout_ids.remove (account);
                }
            }
        }
    }

    private void add_account (Mail.Backend.Account account) {
        Camel.Store? store = (Camel.Store) account.service;

        if (store != null) {
            try {
                var folder = store.get_inbox_folder_sync (null);

                if (folder != null) {
                    var inbox_folder = store.get_folder_sync (folder.full_name, Camel.StoreGetFolderFlags.NONE, null);

                    if (inbox_folder != null) {
                        inbox_folder.changed.connect ((change_info) => {
                            inbox_folder_changed (account, change_info);
                        });

                        lock (inbox_folders) {
                            inbox_folders.insert (account, inbox_folder);
                        }

                        uint refresh_interval_in_minutes = 15;

                        debug ("[%s] Checking inbox for new mail every %u minutes…", folder.display_name, refresh_interval_in_minutes);
                        var refresh_timeout_id = GLib.Timeout.add_seconds (refresh_interval_in_minutes * 60, () => {
                            inbox_folder_synchronize_sync.begin (account);
                            return GLib.Source.CONTINUE;
                        });

                        lock (synchronize_timeout_ids) {
                            synchronize_timeout_ids.insert (account, refresh_timeout_id);
                        }

                        inbox_folder_synchronize_sync.begin (account);
                    }

                } else {
                    debug ("[%s] Inbox folder not found. Can't automatically check for new messages.", account.service.display_name);
                }

            } catch (Error e) {
                debug ("[%s] Error getting inbox folder: %s", account.service.display_name, e.message);
            }

        } else {
            debug ("[%s] No store available.", account.service.display_name);
        }
    }

    private async void inbox_folder_synchronize_sync (Mail.Backend.Account account) {
        if (!network_monitor.network_available) {
            debug ("[%s] Network is not avaible. Skipping…", account.service.display_name);
            return;
        }

        var inbox_folder = inbox_folders.get (account);
        if (inbox_folder != null) {
            debug ("[%s] Refreshing…", account.service.display_name);

            try {
                yield inbox_folder.refresh_info (GLib.Priority.DEFAULT, null);
            } catch (Error e) {
                debug ("[%s] Error refreshing: %s", account.service.display_name, e.message);
            }
        }
    }

    private void inbox_folder_changed (Mail.Backend.Account account, Camel.FolderChangeInfo changes) {
        var inbox_folder = inbox_folders.get (account);
        if (inbox_folder == null) {
            return;
        }

        unowned var added_uids = changes.get_added_uids ();
        if (added_uids != null) {
            var sender_names = new GenericSet<string> (str_hash, str_equal);
            var unseen_message_infos = new SList<Camel.MessageInfo> ();

            added_uids.foreach ((added_uid) => {
                var message_info = inbox_folder.get_message_info (added_uid);

                if (!(Camel.MessageFlags.SEEN in message_info.flags)) {
                    unowned string? sender_address;
                    unowned string? sender_name;

                    var camel_address = new Camel.InternetAddress ();
                    camel_address.unformat (message_info.from);
                    camel_address.get (0, out sender_name, out sender_address);

                    if (sender_name == null) {
                        sender_name = sender_address;
                    }

                    sender_names.add (sender_name);
                    unseen_message_infos.append (message_info);
                }
            });

            var unseen_message_infos_length = unseen_message_infos.length ();
            if (unseen_message_infos_length == 1) {
                var unseen_message_info = unseen_message_infos.nth_data (0);

                var notification = new GLib.Notification (_("%s to %s").printf (sender_names.iterator ().next_value (), inbox_folder.parent_store.display_name));
                notification.set_body (unseen_message_info.subject);
                GLib.Application.get_default ().send_notification (unseen_message_info.uid, notification);

            } else if (unseen_message_infos_length > 1) {
                GLib.Notification notification;

                ///TRANSLATORS: The %s represents the number of new messages translated in your language, e.g. "2 new messages"
                string messages_count = ngettext ("%u new message", "%u new messages", unseen_message_infos_length).printf (unseen_message_infos_length);

                if (sender_names.length == 1) {
                    var sender_name = sender_names.iterator ().next_value ();

                    notification = new GLib.Notification (_("%s to %s").printf (sender_name, inbox_folder.parent_store.display_name));
                    notification.set_body (messages_count);

                } else {
                    notification = new GLib.Notification (inbox_folder.parent_store.display_name);

                    ///TRANSLATORS: The first %s represents the number of new messages translated in your language, e.g. "2 new messages"
                    ///The next %s represents the number of senders
                    notification.set_body (ngettext ("%s from %u sender", "%s from %u senders", sender_names.length).printf (messages_count, sender_names.length));
                }

                GLib.Application.get_default ().send_notification (unseen_message_infos.nth_data (0).uid, notification);
            }
        }
    }
}
