/*
* Copyright (c) 2017-2023 elementary, Inc. (https://elementary.io)
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
* along with this program. If not, see <http://www.gnu.org/licenses/>
*/

public class Mail.Signature : Gtk.ListBoxRow {
    public string title { get; set; }
    public string content { get; set; }
    public string uid { get; private set; }

    private E.Source signature_source;
    private uint timeout_id = 0;

    public async Signature (E.Source signature_source) {
        this.signature_source = signature_source;
        title = signature_source.display_name;
        uid = signature_source.uid;

        try {
            string content;
            size_t length;
            yield signature_source.mail_signature_load (GLib.Priority.DEFAULT, null, out content, out length);
            this.content = content;
        } catch (Error e) {
            warning ("Failed to load signature '%s': %s", title, e.message);
        }

        var label = new Gtk.Label (title) {
            halign = Gtk.Align.START
        };
        this.bind_property ("title", label, "label");

        add (label);
        show_all ();
    }

    public async void save (string new_content) {
        signature_source.display_name = title;
        content = new_content;
        try {
            yield signature_source.mail_signature_replace (new_content, new_content.length, GLib.Priority.DEFAULT, null);
            yield signature_source.write (null);
        } catch (Error e) {
            warning ("Failed to save signature '%s': %s", title, e.message);
        }
    }

    public void undo_delete () {
        if (timeout_id != 0) {
            Source.remove (timeout_id);
            show ();
            timeout_id = 0;
        }
    }

    public void delete_signature () {
        hide ();
        timeout_id = GLib.Timeout.add_seconds (5, () => {
            finish_delete_signature.begin ();
            return Source.REMOVE;
        });
    }

    public async void finish_delete_signature () {
        if (timeout_id != 0) {
            Source.remove (timeout_id);
            timeout_id = 0;
        }

        foreach (var identity_source in Mail.Backend.Session.get_default ().get_all_identity_sources ()) {
            unowned var identity_extension = (E.SourceMailIdentity)identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_IDENTITY);
            if (identity_extension.signature_uid == signature_source.uid) {
                identity_extension.signature_uid = "none";
                try {
                    yield identity_source.write (null);
                } catch (Error e) {
                    warning (
                        "Failed to remove signature '%s' as default for mail address '%s': %s",
                        title,
                        identity_extension.address,
                        e.message
                    );
                }
            }
        }

        try {
            yield signature_source.remove (null);
            destroy ();
        } catch (Error e) {
            warning ("Failed to delete signature '%s': %s", title, e.message);
            show ();
        }
    }
}
