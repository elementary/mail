// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.GroupedFolderItemModel : ItemModel {
    public int unread { get; set; }
    public Camel.FolderInfoFlags folder_type { get; construct; }

    private Gee.HashMap<Mail.Backend.Account, Camel.FolderInfo?> account_folderinfo;

    public GroupedFolderItemModel (Camel.FolderInfoFlags folder_type) {
        Object (folder_type: folder_type);
    }

    construct {
        account_uid = "UNIFIED ACCOUNT";
        account_folderinfo = new Gee.HashMap<Mail.Backend.Account, Camel.FolderInfo?> ();

        switch (folder_type & Camel.FOLDER_TYPE_MASK) {
            case Camel.FolderInfoFlags.TYPE_INBOX:
                name = _("Inbox");
                icon_name = "mail-inbox";
                break;
            case Camel.FolderInfoFlags.TYPE_ARCHIVE:
                name = _("Archive");
                icon_name = ("mail-archive");
                break;
            case Camel.FolderInfoFlags.TYPE_SENT:
                name = _("Sent");
                icon_name = "mail-sent";
                break;
            default:
                name = "%i".printf (folder_type & Camel.FOLDER_TYPE_MASK);
                icon_name = "folder";
                warning ("Unknown grouped folder type: %s", name);
                break;
        }
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

    public void add_account (Mail.Backend.Account account) {
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
                folderinfo = yield offlinestore.get_folder_info (full_name, 0, GLib.Priority.DEFAULT, null);
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

    private void update_infos () {
        var total_unread = 0;
        lock (account_folderinfo) {
            foreach (var entry in account_folderinfo) {
                if (entry.value == null) {
                    continue;
                }
                total_unread += entry.value.unread;
            }
        }
        unread = total_unread;
    }

    private string? build_folder_full_name (Backend.Account account) {
        var session =  Mail.Backend.Session.get_default ();
        var service_source = session.ref_source (account.service.uid);
        if (service_source == null || !service_source.has_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT)) {
            return null;
        }

        var mail_account_extension = (E.SourceMailAccount) service_source.get_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT);
        if (Camel.FolderInfoFlags.TYPE_INBOX == (folder_type & Camel.FOLDER_TYPE_MASK)) {
            if ("ews".ascii_casecmp (mail_account_extension.backend_name) == 0) {
                return "Inbox";
            }
            return "INBOX";
        }

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
            unowned var mail_submission_extension = (E.SourceMailSubmission) identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_SUBMISSION);
            return Utils.strip_folder_full_name (account.service.uid, mail_submission_extension.sent_folder);
        }

        return null;
    }

    public void remove_account (Mail.Backend.Account account) {
        lock (account_folderinfo) {
            account_folderinfo.unset (account);
        }
    }
}
