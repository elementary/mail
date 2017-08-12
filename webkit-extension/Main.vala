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

[DBus (name = "io.elementary.mail.WebViewServer")]
public class DOMServer : Object {
    public signal void selection_changed (uint64 page_id);
    public signal void image_load_blocked (uint64 page_id);

    private const string[] ALLOWED_SCHEMES = { "cid", "data", "about", "elementary-mail" };

    private Gee.HashMap <uint64?, bool> show_images
        = new Gee.HashMap <uint64?, bool> ((Gee.HashDataFunc)int64_hash, (Gee.EqualDataFunc)int64_equal);

    private WebKit.WebExtension extension;

    public DOMServer (WebKit.WebExtension extension) {
        this.extension = extension;

        Bus.own_name (BusType.SESSION, "io.elementary.mail.WebViewServer", BusNameOwnerFlags.NONE,
            on_bus_acquired, null, () => { warning ("Could not acquire name"); });
    }

    private void on_bus_acquired (DBusConnection connection) {
        try {
            connection.register_object ("/io/elementary/mail/WebViewServer", this);
        } catch (IOError error) {
            warning ("Could not register webkit extension DBus object: %s", error.message);
        }
    }

    public int get_page_height (uint64 page_id) {
        var page = extension.get_page (page_id);
        if (page != null) {
            return (int)page.get_dom_document ().get_document_element ().get_offset_height ();
        }
        return 0;
    }

    public void set_image_loading_enabled (uint64 page_id, bool enabled) {
        show_images[page_id] = enabled;
        if (enabled) {
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

    [DBus (visible = false)]
    public void on_page_created (WebKit.WebExtension extension, WebKit.WebPage page) {
        page.send_request.connect (on_send_request);
        page.get_editor ().selection_changed.connect (() => {
            selection_changed (page.get_id ());
        });
    }

    private bool on_send_request (WebKit.WebPage page, WebKit.URIRequest request, WebKit.URIResponse? response) {
        bool should_load = false;
        Soup.URI? uri = new Soup.URI (request.get_uri ());
        if (uri != null && uri.get_scheme () in ALLOWED_SCHEMES) {
            // Always load internal resources
            should_load = true;
        } else {
            if (show_images.has_key (page.get_id ()) && show_images [page.get_id ()]) {
                should_load = true;
            } else {
                image_load_blocked (page.get_id ());
            }
        }

        return should_load ? Gdk.EVENT_PROPAGATE : Gdk.EVENT_STOP;
    }

    public void execute_command (uint64 view, string command, string argument) {
        var page = extension.get_page (view);
        if (page != null) {
            var document = page.get_dom_document ();
            document.exec_command (command, false, argument);
        }
    }

    public bool query_command_state (uint64 view, string command) {
        var page = extension.get_page (view);
        if (page != null) {
            var document = page.get_dom_document ();
            var state = document.query_command_state (command);
            return state;
        }
        return false;
    }

    public string? get_body_html (uint64 view) {
        string? body_html = null;
        var page = extension.get_page (view);
        if (page != null) {
            try {
                body_html = page.get_dom_document ().get_document_element ().query_selector ("body").get_inner_html ();
            } catch (Error e) {
                warning ("Unable to get message body content: %s", e.message);
            }
        }
        return body_html;
    }

    public void set_body_html (uint64 view, string html) {
        var page = extension.get_page (view);
        if (page != null) {
            try {
                page.get_dom_document ().get_document_element ().query_selector ("#message-body").set_inner_html (html);
            } catch (Error e) {
                warning ("Unable to set message body content: %s", e.message);
            }
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
