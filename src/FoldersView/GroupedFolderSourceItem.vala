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

public class Mail.GroupedFolderSourceItem : Granite.Widgets.SourceList.Item {
    public Mail.Backend.Session session { get; construct; }
    public Camel.FolderInfoFlags folder_type { get; construct; }

    private GLib.Cancellable connect_cancellable;
    private Gee.HashMap<Backend.Account, Camel.FolderInfo?> account_folderinfo;

    public GroupedFolderSourceItem (Mail.Backend.Session session, Camel.FolderInfoFlags folder_type) {
        Object (session: session, folder_type: folder_type);
    }

    construct {
        visible = true;
        connect_cancellable = new GLib.Cancellable ();
        account_folderinfo = new Gee.HashMap<Backend.Account, Camel.FolderInfo?> ();

        switch (folder_type & Camel.FOLDER_TYPE_MASK) {
            case Camel.FolderInfoFlags.TYPE_INBOX:
                name = _("Inbox");
                icon = new ThemedIcon ("mail-inbox");
                break;
            case Camel.FolderInfoFlags.TYPE_ARCHIVE:
                name = _("Archive");
                icon = new ThemedIcon ("mail-archive");
                break;
            case Camel.FolderInfoFlags.TYPE_SENT:
                name = _("Sent");
                icon = new ThemedIcon ("mail-sent");
                break;
            default:
                name = "%i".printf (folder_type & Camel.FOLDER_TYPE_MASK);
                icon = new ThemedIcon ("folder");
                warning ("Unknown grouped folder type: %s", name);
                break;
        }

        session.get_accounts ().foreach ((account) => {
            add_account (account);
            return true;
        });

        session.account_added.connect (add_account);
        session.account_removed.connect (removed_account);
    }

    ~GroupedFolderSourceItem () {
        connect_cancellable.cancel ();
    }

    public Gee.Map<Mail.Backend.Account, string?> get_folder_full_name_per_account () {
        var folder_full_name_per_account = new Gee.HashMap<Mail.Backend.Account, string?> ();
        lock (account_folderinfo) {
            foreach (var entry in account_folderinfo) {
                if (entry.value != null) {
                    folder_full_name_per_account.set (entry.key, entry.value.full_name);
                } else {
                    folder_full_name_per_account.set (entry.key, null);
                }
            }
        }
        return folder_full_name_per_account.read_only_view;
    }

    private void add_account (Mail.Backend.Account account) {
        lock (account_folderinfo) {
            account_folderinfo.set (account, null);
        }
        load_folder_info.begin (account);
    }

    private async void load_folder_info (Mail.Backend.Account account) {
        var offlinestore = (Camel.OfflineStore) account.service;
        var full_name = build_folder_full_name (account);
        Camel.FolderInfo? folderinfo = null;

        if (full_name != null) {
            try {
                folderinfo = yield offlinestore.get_folder_info (full_name, 0, GLib.Priority.DEFAULT, connect_cancellable);

            } catch (Error e) {
                // We can cancel the operation
                if (!(e is GLib.IOError.CANCELLED)) {
                    warning ("Unable to fetch %s of account '%s': %s", full_name, account.service.display_name, e.message);
                }
            }
        }

        lock (account_folderinfo) {
            account_folderinfo.set (account, folderinfo);
        }
        update_infos ();
    }

    private void removed_account () {
        var accounts_left = session.get_accounts ();

        foreach (var account in account_folderinfo.keys) {
            if (!accounts_left.contains (account)) {
                lock (account_folderinfo) {
                    account_folderinfo.unset (account);
                }
            }
        }
    }

    private void update_infos () {
        badge = null;
        var total_unread = 0;
        lock (account_folderinfo) {
            foreach (var entry in account_folderinfo) {
                if (entry.value == null) {
                    continue;
                }
                total_unread += entry.value.unread;
            }
        }
        if (total_unread > 0) {
            badge = "%d".printf (total_unread);
        }
    }

    private string? build_folder_full_name (Backend.Account account) {
        if (Camel.FolderInfoFlags.TYPE_INBOX == (folder_type & Camel.FOLDER_TYPE_MASK)) {
            return "INBOX";
        }
        var service_source = session.ref_source (account.service.uid);

        if (service_source != null && service_source.has_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT)) {
            var mail_account_extension = (E.SourceMailAccount) service_source.get_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT);

            if (Camel.FolderInfoFlags.TYPE_ARCHIVE == (folder_type & Camel.FOLDER_TYPE_MASK)) {
                return Utils.strip_folder_full_name (account.service.uid, mail_account_extension.dup_archive_folder ());
            }

            var identity_uid = mail_account_extension.dup_identity_uid ();
            var identity_source = session.ref_source (identity_uid);

            if (
                Camel.FolderInfoFlags.TYPE_SENT == (folder_type & Camel.FOLDER_TYPE_MASK)
                &&
                identity_source.has_extension (E.SOURCE_EXTENSION_MAIL_SUBMISSION)
            ) {
                var mail_submission_extension = (E.SourceMailSubmission) identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_SUBMISSION);
                return Utils.strip_folder_full_name (account.service.uid, mail_submission_extension.dup_sent_folder ());
            }
        }
        return null;
    }
}
