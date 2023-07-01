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
    private const string JS_EXPAND_BODY = """
        var body = document.querySelector('#elementary-message-body');
        var signature = document.querySelector('#elementary-message-signature');
        var quote = document.querySelector('#elementary-message-quote');
        if (!signature.hidden || !quote.hidden) {
            body.style.height = "initial";
        } else {
            body.style.height = "100%";
        }
    """;

    private const string JS_CLEAN_HTML = """
        var body = document.querySelector('#elementary-message-body');
        body.removeAttribute ("contenteditable");
        body.removeAttribute ("id");
        body.style.height = "initial";

        var signature = document.querySelector('#elementary-message-signature');
        if (signature.hidden) {
            signature.remove ();
        } else {
            signature.removeAttribute ("contenteditable");
            signature.removeAttribute ("id");
        }

        var quote = document.querySelector('#elementary-message-quote');
        if (quote.hidden) {
            quote.remove ();
        } else {
            quote.removeAttribute ("contenteditable");
            quote.removeAttribute ("id");
        }
    """;

    private bool show_images = false;
    private List<string> image_uris;
    unowned WebKit.WebPage page;

    public Page (WebKit.WebPage page) {
        this.page = page;
        image_uris = new List<string> ();

        page.send_request.connect (on_send_request);
        page.user_message_received.connect (on_page_user_message_received);
        page.get_editor ().selection_changed.connect (() => {
            page.send_message_to_view.begin (new WebKit.UserMessage ("selection-changed", null), null);

            var js_context = page.get_main_frame ().get_js_context ();
            foreach (var image_uri in image_uris) {
                var val = js_context.evaluate ("""document.querySelector('[src="%s"]')""".printf (image_uri), -1);
                if (val.is_null ()) {
                    unowned List<string> entry = image_uris.find_custom (image_uri, strcmp);
                    image_uris.remove_link (entry);
                    page.send_message_to_view.begin (new WebKit.UserMessage ("image-removed", image_uri), null);
                }
            }
        });
    }

    private bool on_page_user_message_received (WebKit.WebPage page, WebKit.UserMessage message) {
        var js_context = page.get_main_frame ().get_js_context ();
        switch (message.name) {
            case "set-content-of-element":
                string element_selector, content;
                message.parameters.get ("(ss)", out element_selector, out content);

                var element = js_context.evaluate ("document.querySelector('%s')".printf (element_selector), -1);

                if (element.is_null ()) {
                    warning ("HTML element '%s' not found.", element_selector);
                    return true;
                }

                if (element_selector == "#elementary-message-signature" ||
                    element_selector == "#elementary-message-quote") {
                    element.object_set_property ("hidden", new JSC.Value.boolean (js_context, content.strip () == ""));
                }

                element.object_set_property ("innerHTML", new JSC.Value.string (js_context, content));

                js_context.evaluate (JS_EXPAND_BODY, -1);

                return true;
            case "get-body-html":
                if (message.parameters.get_boolean ()) {
                    js_context.evaluate (JS_CLEAN_HTML, -1);
                }
                JSC.Value val = js_context.evaluate ("document.querySelector('body').innerHTML;", -1);
                message.send_reply (new WebKit.UserMessage ("get-body-html", new Variant.take_string (val.to_string ())));
                return true;
            case "set-message":
                unowned string message_html = message.parameters.get_string ();
                var body = js_context.evaluate ("document.querySelector('body')", -1);
                body.object_set_property ("innerHTML", new JSC.Value.string (js_context, message_html));
                js_context.evaluate (JS_EXPAND_BODY, -1);
                return true;
            case "get-page-height":
                JSC.Value val = js_context.evaluate ("""
                Math.max(
                    document.body.scrollHeight, document.body.offsetHeight,
                    document.documentElement.clientHeight, document.documentElement.scrollHeight, document.documentElement.offsetHeight
                );
                """, -1);
                message.send_reply (new WebKit.UserMessage ("get-page-height", new Variant.int32 (val.to_int32 ())));
                return true;
            case "set-image-loading-enabled":
                var enabled = message.parameters.get_boolean ();
                show_images = enabled;
                if (enabled) {
                    js_context.evaluate (
                        """var images = document.images;
                        for(var i = 0; i < images.length; i++) {
                            images[i].src = images[i].src
                        }""",
                        -1
                    );
                }

                return true;
            case "execute-editor-command":
                string command, argument;
                message.parameters.get ("(ss)", out command, out argument);
                var document = js_context.evaluate ("document", -1);
                JSC.Value[] parameters = {
                    new JSC.Value.string (js_context, command),
                    new JSC.Value.boolean (js_context, false),
                    new JSC.Value.string (js_context, argument)
                };

                if (command == "insertImage") {
                    image_uris.append (argument);
                }

                var ret = document.object_invoke_methodv ("execCommand", parameters);
                if (!ret.is_boolean () || ret.to_boolean () == false) {
                    critical (ret.to_string ());
                }

                return true;
            case "query-command-state":
                unowned string command = message.parameters.get_string ();
                var document = js_context.evaluate ("document", -1);
                JSC.Value[] parameters = {
                    new JSC.Value.string (js_context, command),
                };
                var ret = document.object_invoke_methodv ("queryCommandState", parameters);
                if (ret.is_boolean ()) {
                    message.send_reply (new WebKit.UserMessage ("query-command-state", new Variant.boolean (ret.to_boolean ())));
                } else {
                    critical (ret.to_string ());
                }

                return true;
            case "get-selected-text":
                JSC.Value val = js_context.evaluate ("document.defaultView.getSelection().getRangeAt(0).toString();", -1);
                if (val.is_string ()) {
                    message.send_reply (new WebKit.UserMessage ("get-selected-text", new Variant.string (val.to_string ())));
                } else {
                    critical ("no selection range: %s", val.to_string ());
                }

                return true;
            default:
                critical ("Unhandled message name: %s", message.name);
                break;
        }

        return false;
    }

    private bool on_send_request (WebKit.WebPage page, WebKit.URIRequest request, WebKit.URIResponse? response) {
        bool should_load = false;
#if HAS_SOUP_3
        GLib.Uri? uri = null;
        try {
            uri = GLib.Uri.parse (request.get_uri (), GLib.UriFlags.NONE);
        } catch (Error e) {
            warning ("Could not parse uri: %s", e.message);
            return should_load;
        }
#else
        Soup.URI? uri = new Soup.URI (request.get_uri ());
#endif
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
