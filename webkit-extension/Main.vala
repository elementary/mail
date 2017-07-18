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
    }
}

public class DOMServer : Object {
    private const string[] ALLOWED_SCHEMES = { "cid", "data" };

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
    }

    private void on_page_load_changed (uint64 page_id) {
        var page = extension.get_page (page_id);
        if (page != null) {
            ui_process.set_height (page_id, (int)page.get_dom_document ().get_document_element ().get_offset_height ());
        }
    }

    public void on_page_created (WebKit.WebExtension extension, WebKit.WebPage page) {
        page.send_request.connect (on_send_request);
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
}

namespace WebkitWebExtension {
    [CCode (cname = "G_MODULE_EXPORT webkit_web_extension_initialize", instance_pos = -1)]
    public void initialize (WebKit.WebExtension extension) {
        DOMServer server = new DOMServer (extension);
        extension.page_created.connect (server.on_page_created);
        server.ref ();
    }
}
