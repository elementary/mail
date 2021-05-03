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
    private GLib.SList<Backend.Account> accounts;
    private Gee.HashMap<string, Camel.FolderInfo> folderinfos;

    public GroupedFolderSourceItem (Mail.Backend.Session session, Camel.FolderInfoFlags folder_type) {
        Object (session: session, folder_type: folder_type);
    }

    construct {
        visible = true;
        connect_cancellable = new GLib.Cancellable ();
        accounts = new GLib.SList<Backend.Account> ();
        folderinfos = new Gee.HashMap<string, Camel.FolderInfo> ();

        switch (folder_type & Camel.FOLDER_TYPE_MASK) {
            case Camel.FolderInfoFlags.TYPE_INBOX:
                name = _("Inbox");
                icon = new ThemedIcon ("mail-inbox");
                break;
            case Camel.FolderInfoFlags.TYPE_DRAFTS:
                name = _("Drafts");
                icon = new ThemedIcon ("folder-documents");
                break;
            case Camel.FolderInfoFlags.TYPE_SENT:
                name = _("Sent");
                icon = new ThemedIcon ("mail-sent");
                break;
            case Camel.FolderInfoFlags.TYPE_ARCHIVE:
                name = _("Archive");
                icon = new ThemedIcon ("mail-archive");
                break;
            default:
                name = "%d".printf (folder_type & Camel.FOLDER_TYPE_MASK);
                icon = new ThemedIcon ("folder");
                warning ("Unsupported group folder type: %d", folder_type & Camel.FOLDER_TYPE_MASK);
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

    public Backend.Account[] get_accounts () {
        var accounts = new Backend.Account[this.accounts.length ()];

        for (var i = 0; i < this.accounts.length (); i++) {
            accounts[i] = this.accounts.nth_data (i);
        }
        return accounts;
    }

    public string?[] get_folder_full_names () {
        var account_full_names = new string?[accounts.length ()];

        for (var i = 0; i < accounts.length (); i++) {
            account_full_names[i] = null;

            var account = accounts.nth_data (i);
            if (folderinfos.has_key (account.service.uid)) {
                var folderinfo = folderinfos.get (account.service.uid);
                account_full_names[i] = folderinfo.full_name;
            }
        }
        return account_full_names;
    }

    private void add_account (Mail.Backend.Account account) {
        load.begin (account);
    }

    private async void load (Mail.Backend.Account account) {
        var folder_full_name = get_folder_full_name (account.service.uid, folder_type);
        Camel.FolderInfo? account_folder_info = null;

        if (folder_full_name != null) {
            var offlinestore = (Camel.OfflineStore) account.service;

            try {
                account_folder_info = yield offlinestore.get_folder_info (folder_full_name, 0, GLib.Priority.DEFAULT, connect_cancellable);
            } catch (Error e) {
                // We can cancel the operation
                if (!(e is GLib.IOError.CANCELLED)) {
                    warning ("Unable to load grouped folder '%s' of account '%s': %s", folder_full_name, account.service.display_name, e.message);
                }
            }
        }

        if (account_folder_info != null) {
            lock (folderinfos) {
                folderinfos.set (account.service.uid, account_folder_info);
            }

            lock (accounts) {
                accounts.append (account);

                if (accounts.length () > 2) {
                    visible = true;
                }
            }

        } else {
            warning ("Grouped folder '%s' not available for account '%s'", folder_full_name, account.service.display_name);
        }
    }

    private void removed_account () {
        var accounts_left = session.get_accounts ();

        for (var i = 0; i < accounts.length (); i++) {
            var account = accounts.nth_data (i);

            if (accounts_left.index_of (account) == -1) {
                lock (folderinfos) {
                    folderinfos.unset (account.service.uid);
                }

                lock (accounts) {
                    accounts.remove (account);
                }
                i = 0;
            }
        }
    }

    private string? get_folder_full_name (string service_uid, Camel.FolderInfoFlags folder_type) {
        if (Camel.FolderInfoFlags.TYPE_INBOX == (folder_type & Camel.FOLDER_TYPE_MASK)) {
            return "INBOX";
        }
        var service_source = session.ref_source (service_uid);

        if (service_source != null && service_source.has_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT)) {
            var mail_account_extension = (E.SourceMailAccount) service_source.get_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT);

            if (Camel.FolderInfoFlags.TYPE_ARCHIVE == (folder_type & Camel.FOLDER_TYPE_MASK)) {
                return build_folder_full_name (service_uid, mail_account_extension.dup_archive_folder ());
            }

            var identity_uid = mail_account_extension.dup_identity_uid ();
            var identity_source = session.ref_source (identity_uid);

            switch (folder_type & Camel.FOLDER_TYPE_MASK) {
                case Camel.FolderInfoFlags.TYPE_DRAFTS:
                    if (identity_source.has_extension (E.SOURCE_EXTENSION_MAIL_COMPOSITION)) {
                        var mail_composition_extension = (E.SourceMailComposition) identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_COMPOSITION);
                        return build_folder_full_name (service_uid, mail_composition_extension.dup_drafts_folder ());
                    }
                    break;

                case Camel.FolderInfoFlags.TYPE_SENT:
                    if (identity_source.has_extension (E.SOURCE_EXTENSION_MAIL_SUBMISSION)) {
                        var mail_submission_extension = (E.SourceMailSubmission) identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_SUBMISSION);
                        return build_folder_full_name (service_uid, mail_submission_extension.dup_sent_folder ());
                    }
                    break;
            }
        }
        return null;
    }

    private string build_folder_full_name (string service_uid, string folder_uri) {
        return folder_uri.replace ("folder://%s/".printf (service_uid), "");
    }
}
