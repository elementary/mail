/*-
 * Copyright 2020 elementary, Inc. (https://elementary.io)
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
 *              Corentin Noël <corentin@elementary.io>
 */

public class Mail.Page : Object {
    private const string[] ALLOWED_SCHEMES = { "cid", "data", "about", "elementary-mail" };

    private bool show_images = false;
    unowned WebKit.WebPage page;

    public Page (WebKit.WebPage page) {
        this.page = page;
        page.send_request.connect (on_send_request);
        page.user_message_received.connect (on_page_user_message_received);
        page.get_editor ().selection_changed.connect (() => {
            page.send_message_to_view.begin (new WebKit.UserMessage ("selection-changed", null), null);
        });
    }

    private bool on_page_user_message_received (WebKit.WebPage page, WebKit.UserMessage message) {
        switch (message.name) {
            case "set-body-html":
                unowned string body = message.parameters.get_string ();
                try {
                    page.get_dom_document ().get_document_element ().query_selector ("#message-body").set_inner_html (body);
                    return true;
                } catch (Error e) {
                    warning ("Unable to set message body content: %s", e.message);
                }

                return false;
            case "get-body-html":
                try {
                    var body_html = page.get_dom_document ().get_document_element ().query_selector ("body").get_inner_html ();
                    message.send_reply (new WebKit.UserMessage ("get-body-html", new Variant.take_string ((owned) body_html)));
                    return true;
                } catch (Error e) {
                    warning ("Unable to get message body content: %s", e.message);
                }

                return false;
            case "get-page-height":
                var height = (int32)page.get_dom_document ().get_document_element ().get_offset_height ();
                message.send_reply (new WebKit.UserMessage ("get-page-height", new Variant.int32 (height)));
                return true;
            case "set-image-loading-enabled":
                var enabled = message.parameters.get_boolean ();
                show_images = enabled;
                if (enabled) {
                    var images = page.get_dom_document ().get_images ();
                    for (int i = 0; i < images.length; i++) {
                        var image = (WebKit.DOM.HTMLImageElement)images.item (i);
                        image.set_src (image.get_src ());
                    }
                }

                return true;
            case "execute-editor-command":
                string command, argument;
                message.parameters.get ("(ss)", out command, out argument);
                var document = page.get_dom_document ();
                document.exec_command (command, false, argument);
                return true;
            case "query-command-state":
                unowned string command = message.parameters.get_string ();
                var document = page.get_dom_document ();
                var state = document.query_command_state (command);
                message.send_reply (new WebKit.UserMessage ("query-command-state", new Variant.boolean (state)));
                return true;
            case "get-selected-text":
                try {
                    var selection_range = page.get_dom_document ().default_view.get_selection ().get_range_at (0);
                    if (selection_range != null) {
                        message.send_reply (new WebKit.UserMessage ("get-selected-text", new Variant.string (selection_range.text)));
                        return true;
                    } else {
                        debug ("no selection range");
                    }
                } catch (Error e) {
                    warning (e.message);
                }

                break;
            default:
                critical ("Unhandled message name: %s", message.name);
                break;
        }

        return false;
    }

    private bool on_send_request (WebKit.WebPage page, WebKit.URIRequest request, WebKit.URIResponse? response) {
        bool should_load = false;
        Soup.URI? uri = new Soup.URI (request.get_uri ());
        if (uri != null && uri.get_scheme () in ALLOWED_SCHEMES) {
            // Always load internal resources
            should_load = true;
        } else {
            if (show_images) {
                should_load = true;
            } else {
                page.send_message_to_view.begin (new WebKit.UserMessage ("image-load-blocked", null), null);
            }
        }

        return should_load ? Gdk.EVENT_PROPAGATE : Gdk.EVENT_STOP;
    }
}
