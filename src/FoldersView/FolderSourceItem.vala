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

public class Mail.FolderSourceItem : Granite.Widgets.SourceList.ExpandableItem {
    public signal void refresh ();

    public string full_name;
    public Backend.Account account { get; construct; }

    private bool can_modify = true;

    public FolderSourceItem (Backend.Account account, Camel.FolderInfo folderinfo) {
        Object (account: account);
        update_infos (folderinfo);
    }

    public override Gtk.Menu? get_context_menu () {
        var menu = new Gtk.Menu ();
        var refresh_item = new Gtk.MenuItem.with_label (_("Refresh folder"));
        menu.add (refresh_item);
        menu.show_all ();

        refresh_item.activate.connect (() => refresh ());
        return menu;
    }

    public void update_infos (Camel.FolderInfo folderinfo) {
        name = folderinfo.display_name;
        full_name = folderinfo.full_name;
        if (folderinfo.unread > 0) {
            badge = "%d".printf (folderinfo.unread);
        }

        var full_folder_info_flags = get_full_folder_info_flags (folderinfo);
        switch (full_folder_info_flags & Camel.FOLDER_TYPE_MASK) {
            case Camel.FolderInfoFlags.TYPE_INBOX:
                icon = new ThemedIcon ("mail-inbox");
                can_modify = false;
                break;
            case Camel.FolderInfoFlags.TYPE_OUTBOX:
                icon = new ThemedIcon ("mail-outbox");
                can_modify = false;
                break;
            case Camel.FolderInfoFlags.TYPE_TRASH:
                icon = new ThemedIcon (folderinfo.total == 0 ? "user-trash" : "user-trash-full");
                can_modify = false;
                badge = null;
                break;
            case Camel.FolderInfoFlags.TYPE_JUNK:
                icon = new ThemedIcon ("edit-flag");
                can_modify = false;
                break;
            case Camel.FolderInfoFlags.TYPE_SENT:
                icon = new ThemedIcon ("mail-sent");
                can_modify = false;
                break;
            case Camel.FolderInfoFlags.TYPE_ARCHIVE:
                icon = new ThemedIcon ("mail-archive");
                can_modify = false;
                badge = null;
                break;
            case Camel.FolderInfoFlags.TYPE_DRAFTS:
                icon = new ThemedIcon ("folder-documents");
                can_modify = false;
                break;
            default:
                icon = new ThemedIcon ("folder");
                can_modify = true;
                break;
        }
    }

    private Camel.FolderInfoFlags get_full_folder_info_flags (Camel.FolderInfo folderinfo) {
        Camel.FolderInfoFlags full_flags = folderinfo.flags;

        var folder_uri = build_folder_uri (account.service.get_uid (), folderinfo.full_name);
        var session = Mail.Backend.Session.get_default ();

        var account_source = session.ref_source (account.source_uid);
        if (account_source != null) {
            var mail_account_extension = (E.SourceMailAccount?) account_source.get_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT);
            
            if (mail_account_extension != null && mail_account_extension.dup_archive_folder () == folder_uri) {
                full_flags = full_flags | Camel.FolderInfoFlags.TYPE_ARCHIVE;
            }
        }

        var service_source = session.ref_source (account.service.uid);
        var service_mail_account_extension = (E.SourceMailAccount?) service_source.get_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT);

        if (service_mail_account_extension != null) {
            var identity_uid = service_mail_account_extension.dup_identity_uid ();
            var identity_source = session.ref_source (identity_uid);

            if (identity_source != null) {
                var mail_composition_extension = (E.SourceMailComposition?) identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_COMPOSITION);
                var mail_submission_extension = (E.SourceMailSubmission?) identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_SUBMISSION);

                if (mail_composition_extension != null && mail_composition_extension.dup_drafts_folder () == folder_uri) {
                    full_flags = full_flags | Camel.FolderInfoFlags.TYPE_DRAFTS;

                } else if (mail_submission_extension != null && mail_submission_extension.dup_sent_folder () == folder_uri) {
                    full_flags = full_flags | Camel.FolderInfoFlags.TYPE_SENT;
                }
            }
        }

        return full_flags;
    }

    private string build_folder_uri (string service_uid, string folder_name) {
        var normed_folder_name = folder_name;

        // Skip the leading slash, if present.
        if (normed_folder_name.has_prefix ("/") ) {
            normed_folder_name = normed_folder_name.substring (1);
        }

        var encoded_service_uid = Camel.URL.encode (service_uid, ":;@/");
        var encoded_normed_folder_name = Camel.URL.encode (normed_folder_name, ":;@?#");

        return "folder://%s/%s".printf (encoded_service_uid, encoded_normed_folder_name);
    }
}
