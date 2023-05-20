/*
* Copyright (c) 2017-2018 elementary, Inc. (https://elementary.io)
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


public class SignatureDialog : Granite.Dialog {
    public signal void set_signature (string signature);

    construct {
        var entry_label = new Gtk.Label (_("Signature:")) {
            halign = END
        };

        var entry = new Gtk.Entry () {
            hexpand = true,
            vexpand = true,
            activates_default = true,
            placeholder_text = _("Name, Organisation")
        };

        var grid = new Gtk.Grid () {
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 12,
            column_spacing = 6,
            row_spacing = 6
        };
        grid.attach (entry_label, 0, 0);
        grid.attach (entry, 1, 0);
        grid.show_all ();

        get_content_area ().add (grid);

        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        var insert_button = add_button (_("Apply"), Gtk.ResponseType.APPLY);
        insert_button.can_default = true;
        insert_button.has_default = true;
        insert_button.sensitive = false;
        insert_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        deletable = false;
        modal = true;

        entry.changed.connect (() => {
            insert_button.sensitive = entry.text.strip () != "";
        });

        response.connect ((response_id) => {
            switch (response_id) {
                case Gtk.ResponseType.APPLY:
                    set_signature (entry.text);
                    destroy ();
                    break;
                case Gtk.ResponseType.CANCEL:
                    destroy ();
                    break;
            }
        });
    }
}
