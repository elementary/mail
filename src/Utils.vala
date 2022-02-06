// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
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

public class Mail.Utils {

    public delegate bool AcceptAddress (string address);
    public static string get_reply_addresses (string raw_addresses, AcceptAddress should_add) {
        var own_addresses = Backend.Session.get_default ().get_own_addresses ();
        var output = "";
        var added_addresses = new Gee.ArrayList<string> ();

        var addresses = new Camel.InternetAddress ();
        addresses.decode (raw_addresses);
        addresses.ref ();
        for (int i = 0; i < addresses.length (); i++) {
            unowned string? _address;
            addresses.@get (i, null, out _address);
            if (_address == null) {
                continue;
            }

            var address = _address.casefold ();
            var is_own_address = false;
            foreach (var own_address in own_addresses) {
                if (address.contains (own_address)) {
                    is_own_address = true;
                    break;
                }
            }

            if (!is_own_address && should_add (address) && !added_addresses.contains (address)) {
                added_addresses.add (address);
                if (output.length > 0) {
                    output += ", %s".printf (address);
                } else {
                    output += address;
                }
            }
        }

        return output;
    }

    public static string escape_html_tags (string input) {
        return input.replace ("<", "&lt;").replace (">", "&gt;");
    }

    public static string? strip_folder_full_name (string service_uid, string? folder_uri) {
        if (folder_uri != null) {
            return folder_uri.replace ("folder://%s/".printf (service_uid), "");
        }

        return null;
    }

    public static Camel.FolderInfoFlags get_full_folder_info_flags (Camel.Service service, Camel.FolderInfo folderinfo) {
        Camel.FolderInfoFlags full_flags = folderinfo.flags;

        var folder_uri = build_folder_uri (service.uid, folderinfo.full_name);
        var session = Mail.Backend.Session.get_default ();
        var service_source = session.ref_source (service.uid);

        if (service_source != null && service_source.has_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT)) {
            var mail_account_extension = (E.SourceMailAccount) service_source.get_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT);

            if (mail_account_extension.dup_archive_folder () == folder_uri) {
                full_flags = full_flags | Camel.FolderInfoFlags.TYPE_ARCHIVE;
            }

            var identity_uid = mail_account_extension.dup_identity_uid ();
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

    public static string build_folder_uri (string service_uid, string folder_name) {
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
