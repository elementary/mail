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


public class InsertLinkDialog : Granite.Dialog {
    public signal void insert_link (string url, string title);

    public string? selected_text { get; construct; }

    public InsertLinkDialog (string? text) {
        Object (selected_text: text);
    }

    construct {
        var url_label = new Gtk.Label (_("URL:")) {
            halign = END
        };

        var url_entry = new Gtk.Entry () {
            activates_default = true,
            input_purpose = URL,
            placeholder_text = _("https://example.com")
        };

        var title_label = new Gtk.Label (_("Link Text:")) {
            halign = END
        };

        var title_entry = new Gtk.Entry () {
            activates_default = true,
            placeholder_text = _("Example Website")
        };
        if (selected_text != null) {
            title_entry.text = selected_text;
        }

        var grid = new Gtk.Grid () {
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 12,
            column_spacing = 6,
            row_spacing = 6
        };
        grid.attach (url_label, 0, 0);
        grid.attach (url_entry, 1, 0);
        grid.attach (title_label, 0, 1);
        grid.attach (title_entry, 1, 1);
        grid.show_all ();

        get_content_area ().add (grid);

        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        var insert_button = add_button (_("Insert Link"), Gtk.ResponseType.APPLY);
        insert_button.can_default = true;
        insert_button.has_default = true;
        insert_button.sensitive = false;
        insert_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        deletable = false;
        modal = true;

        url_entry.changed.connect (() => {
            bool is_valid = false;
            string url_entry_text = url_entry.text;

            if (url_entry_text == "") {
                url_entry.secondary_icon_name = null;
            } else if (validate_url (url_entry_text)) {
                is_valid = true;
                url_entry.secondary_icon_name = "process-completed-symbolic";
            } else {
                url_entry.secondary_icon_name = "process-error-symbolic";
            }

            insert_button.sensitive = is_valid;
        });

        response.connect ((response_id) => {
            switch (response_id) {
                case Gtk.ResponseType.APPLY:
                    insert_link (url_entry.text, title_entry.text);
                    destroy ();
                    break;
                case Gtk.ResponseType.CANCEL:
                    destroy ();
                    break;
            }
        });
    }

    private bool validate_url (string url) {
        try {
            var regex = new Regex ("""^(?:http(s)?:\/\/)?[\w.-]+(?:\.[\w\.-]+)+[\w\-\._~:/?#[\]@!\$&'\(\)\*\+,;=.%]+$""");
            return regex.match (url);
        } catch (Error e) {
            critical ("Could not create URL Regex %s", e.message);
            return true;
        }
    }
}
