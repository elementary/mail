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
    }
}

public class DOMServer : Object {
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
}

namespace WebkitWebExtension {
    [CCode (cname = "G_MODULE_EXPORT webkit_web_extension_initialize", instance_pos = -1)]
    public void initialize (WebKit.WebExtension extension) {
        DOMServer server = new DOMServer (extension);
        server.ref ();
    }
}
