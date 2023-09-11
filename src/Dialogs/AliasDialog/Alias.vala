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
*
* Authored by: Leonhard Kargl <leo.kargl@proton.me>
*/

public class Mail.Alias : Gtk.ListBoxRow {
    public signal void save (string old_address);

    public string address { get; set construct; }
    public string? alias_name { get; set construct; }
    public bool is_deleted { get; private set; default = false; }

    private string old_address;

    public Alias (string address, string? alias_name) {
        Object (
            address: address,
            alias_name: alias_name
        );
    }

    construct {
        old_address = address;

        var name_label = new Gtk.Label (alias_name ?? "Name not set") {
            hexpand = true,
            xalign = 0
        };

        var address_label = new Gtk.Label (address) {
            halign = END
        };
        bind_property ("address", address_label, "label", DEFAULT);

        var edit_name_label = new Gtk.Label (_("Name:")) {
            halign = END
        };

        var name_entry = new Gtk.Entry () {
            text = name_label.label
        };
        name_entry.bind_property ("text", this, "alias-name", DEFAULT);

        var edit_address_label = new Gtk.Label (_("Address:")) {
            halign = END
        };

        Regex? regex = null;
        try {
            regex = new Regex ("""(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9][0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])""");
        } catch (Error e) {
            warning ("Failed to create regex: %s", e.message);
        }

        var address_entry = new Granite.ValidatedEntry.from_regex (regex) {
            text = address
        };
        address_entry.bind_property ("text", this, "address", BIDIRECTIONAL);

        var delete_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic") {
            halign = END
        };

        var edit_popover_content = new Gtk.Grid () {
            margin_start = 3,
            margin_end = 3,
            margin_top = 3,
            margin_bottom = 3,
            column_spacing = 3,
            row_spacing = 3
        };
        edit_popover_content.attach (edit_name_label, 0, 0);
        edit_popover_content.attach (name_entry, 1, 0);
        edit_popover_content.attach (edit_address_label, 0, 1);
        edit_popover_content.attach (address_entry, 1, 1);
        edit_popover_content.attach (delete_button, 1, 2);
        edit_popover_content.show_all ();

        var edit_popover = new Gtk.Popover (null) {
            child = edit_popover_content
        };

        var edit_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("document-edit-symbolic", BUTTON),
            popover = edit_popover
        };

        var box = new Gtk.Box (HORIZONTAL, 3) {
            margin_start = 3,
            margin_end = 3,
            margin_top = 3,
            margin_bottom = 3
        };
        box.add (name_label);
        box.add (address_label);
        box.add (new Gtk.Separator (VERTICAL));
        box.add (edit_button);

        child = box;
        show_all ();

        edit_popover.closed.connect (() => {
            if (address_entry.is_valid) {
                save (old_address);
            } else {
                address = old_address;
            }
        });

        notify["alias-name"].connect (() => {
            if (alias_name.strip () == "") {
                name_label.label = "Name not set";
            } else {
                name_label.label = alias_name;
            }
        });

        save.connect (() => {
            old_address = address;
        });
    }

    // public void undo_delete () {
    //     if (timeout_id != 0) {
    //         Source.remove (timeout_id);
    //         timeout_id = 0;
    //     }
    // }

    // public void delete_signature () {
    //     timeout_id = GLib.Timeout.add_seconds (5, () => {
    //         finish_delete_signature.begin ();
    //         return Source.REMOVE;
    //     });
    // }

    // public async void finish_delete_signature () {
    //     if (timeout_id != 0) {
    //         Source.remove (timeout_id);
    //         timeout_id = 0;
    //     }

    //     foreach (var identity_source in Mail.Backend.Session.get_default ().get_all_identity_sources ()) {
    //         unowned var identity_extension = (E.SourceMailIdentity)identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_IDENTITY);
    //         if (identity_extension.signature_uid == signature_source.uid) {
    //             identity_extension.signature_uid = "none";
    //             try {
    //                 yield identity_source.write (null);
    //             } catch (Error e) {
    //                 warning (
    //                     "Failed to remove signature '%s' as default for mail address '%s': %s",
    //                     title,
    //                     identity_extension.address,
    //                     e.message
    //                 );
    //             }
    //         }
    //     }

    //     try {
    //         yield signature_source.remove (null);
    //         destroy ();
    //     } catch (Error e) {
    //         warning ("Failed to delete signature '%s': %s", title, e.message);
    //     }
    // }
}
