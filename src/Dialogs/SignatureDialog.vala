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
    private const string HTML = """<!DOCTYPE html>
    <html>
    <head>
        <title></title>
        <style>
            :root {
                --bg-color: white;
                --fg-color: black;
            }

            @media (prefers-color-scheme: dark) {
                :root {
                    --bg-color: #3A3A3A;
                    --fg-color: white;
                }
            }

            html {
                height: 100%;
            }
            body {
                margin: 0px !important;
                padding: 0 !important;
                background-color: var(--bg-color) !important;
                color: var(--fg-color);
                font-size: medium !important;
                height: 100% !important;
                box-sizing: border-box;
                padding: 6px !important;
                outline: 0px solid transparent;
            }
            body.plain, body.plain * {
                font-family: monospace !important;
                font-weight: normal;
                font-style: normal;
                font-size: medium !important;
                color: var(--fg-color);
                text-decoration: none;
            }
            body.plain a {
                cursor: text;
            }
        </style>
    </head>
    <body>
        %s
    </body>
    </html>""";

    private Camel.Service service;
    private Mail.WebView web_view;

    public SignatureDialog (Camel.Service service) {
        this.service = service;

        var entry_label = new Gtk.Label (_("Signature:")) {
            halign = START
        };

        web_view = new Mail.WebView () {
            is_composer = true,
            height_request = 150,
            width_request = 350,
            editable = true
        };
        get_signature.begin ();

        var box = new Gtk.Box (VERTICAL, 6) {
            margin_start = 12,
            margin_end = 12
        };
        box.add (entry_label);
        box.add (web_view);
        box.show_all ();

        get_content_area ().add (box);

        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        var insert_button = add_button (_("Update"), Gtk.ResponseType.APPLY);
        insert_button.can_default = true;
        insert_button.has_default = true;
        insert_button.sensitive = true;
        insert_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        deletable = false;
        modal = true;

        response.connect ((response_id) => {
            switch (response_id) {
                case Gtk.ResponseType.APPLY:
                    set_signature.begin ();
                    break;
                case Gtk.ResponseType.CANCEL:
                    destroy ();
                    break;
            }
        });
    }

    private async void get_signature () {
        unowned var session = Mail.Backend.Session.get_default ();
        var signature = yield session.get_signature_for_service (service);
        web_view.load_html (HTML.printf (signature));
    }

    private async void set_signature () {
        unowned var session = Mail.Backend.Session.get_default ();
        var signature = yield web_view.get_message_html ();
        session.set_signature_for_service.begin (service, signature);
        destroy ();
    }
}
