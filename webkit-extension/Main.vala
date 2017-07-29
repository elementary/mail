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

namespace MailWebViewExtension {
    [DBus (name = "io.elementary.mail.WebViewServer")]
    interface Server : Object {
        public signal void page_load_changed (uint64 page_id);
        public abstract void set_height (uint64 view, int height);

        public abstract void fire_image_load_blocked (uint64 page_id);
        public signal void image_loading_enabled (uint64 page_id);
        public abstract bool get_load_images (uint64 view);

        public signal void command_executed (uint64 view, string command);
        public signal void query_command_state (uint64 view, string command);
        public abstract void fire_command_state_updated (uint64 view, string command, bool state);

        public abstract void fire_selection_changed (uint64 view);
    }
}

public class DOMServer : Object {
    private const string[] ALLOWED_SCHEMES = { "cid", "data", "about", "elementary-mail" };

    private WebKit.WebExtension extension;

    private MailWebViewExtension.Server? ui_process = null;

    public DOMServer (WebKit.WebExtension extension) {
        this.extension = extension;
        try {
            ui_process = Bus.get_proxy_sync (BusType.SESSION, "io.elementary.mail.WebViewServer", "/io/elementary/mail/WebViewServer");
        } catch (IOError e) {
            warning ("WebKit extension couldn't connect to UI interface: %s", e.message);
        }
        ui_process.page_load_changed.connect (on_page_load_changed);
        ui_process.image_loading_enabled.connect (on_image_loading_enabled);
        ui_process.command_executed.connect (on_command_executed);
        ui_process.query_command_state.connect (on_query_command_state);
    }

    private void on_page_load_changed (uint64 page_id) {
        var page = extension.get_page (page_id);
        if (page != null) {
            ui_process.set_height (page_id, (int)page.get_dom_document ().get_document_element ().get_offset_height ());
        }
    }

    private void on_image_loading_enabled (uint64 page_id) {
        if (ui_process.get_load_images (page_id)) {
            var page = extension.get_page (page_id);
            if (page != null) {
                var images = page.get_dom_document ().get_images ();
                for (int i = 0; i < images.length; i++) {
                    var image = (WebKit.DOM.HTMLImageElement)images.item (i);
                    image.set_src (image.get_src ());
                }
            }
        }
    }

    public void on_page_created (WebKit.WebExtension extension, WebKit.WebPage page) {
        page.send_request.connect (on_send_request);
        page.get_editor ().selection_changed.connect (() => {
            ui_process.fire_selection_changed (page.get_id ());
        });
    }

    private bool on_send_request (WebKit.WebPage page, WebKit.URIRequest request, WebKit.URIResponse? response) {
        bool should_load = false;
        Soup.URI? uri = new Soup.URI (request.get_uri ());
        if (uri != null && uri.get_scheme () in ALLOWED_SCHEMES) {
            // Always load internal resources
            should_load = true;
        } else {
            if (ui_process.get_load_images (page.get_id ())) {
                should_load = true;
            } else {
                ui_process.fire_image_load_blocked (page.get_id ());
            }
        }

        return should_load ? Gdk.EVENT_PROPAGATE : Gdk.EVENT_STOP;
    }

    private void on_command_executed (uint64 view, string command) {
        var page = extension.get_page (view);
        if (page != null) {
            var document = page.get_dom_document ();
            document.exec_command (command, false, "");
        }
    }

    private void on_query_command_state (uint64 view, string command) {
        var page = extension.get_page (view);
        if (page != null) {
            var document = page.get_dom_document ();
            var state = document.query_command_state (command);
            ui_process.fire_command_state_updated (view, command, state);
        }
    }
}

namespace WebkitWebExtension {
    [CCode (cname = "G_MODULE_EXPORT webkit_web_extension_initialize", instance_pos = -1)]
    public void initialize (WebKit.WebExtension extension) {
        DOMServer server = new DOMServer (extension);
        extension.page_created.connect (server.on_page_created);
        server.ref ();
    }
}
