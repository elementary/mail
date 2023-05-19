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

public extern const string WEBKIT_EXTENSION_PATH;

public class Mail.WebView : WebKit.WebView {
    public signal void image_load_blocked ();
    public signal void link_activated (string url);
    public signal void selection_changed ();
    public signal void load_finished ();

    public bool body_html_changed { get; private set; default = false; }

    private const string INTERNAL_URL_BODY = "elementary-mail:body";
    private const string SERVER_BUS_NAME = "io.elementary.mail.WebViewServer";

    private Gee.Map<string, InputStream> internal_resources;

    private bool loaded = false;
    private bool queued_load_images = false;
    private string? queued_body_content = null;
    private string? queued_signature_content = null;
    private string? queued_quote_content = null;
    private string? queued_body_html = null;
    public bool is_composer { get; set; default = false; }
    private GLib.Cancellable cancellable;

    static construct {
        unowned WebKit.WebContext context = WebKit.WebContext.get_default ();
        unowned string? webkit_extension_path_env = Environment.get_variable ("WEBKIT_EXTENSION_PATH");
        context.set_web_extensions_directory (webkit_extension_path_env ?? WEBKIT_EXTENSION_PATH);
        context.set_sandbox_enabled (true);

        context.register_uri_scheme ("cid", (req) => {
            WebView? view = req.get_web_view () as WebView;
            if (view != null) {
                view.handle_cid_request (req);
            }
        });
    }

    construct {
        cancellable = new GLib.Cancellable ();
        vexpand = true;
        hexpand = true;

        internal_resources = new Gee.HashMap<string, InputStream> ();

        decide_policy.connect (on_decide_policy);
        load_changed.connect (on_load_changed);
        resource_load_started.connect ((resource) => {
            resource.finished.connect (() => update_height ());
        });

        key_release_event.connect (() => {
            body_html_changed = true;
        });
    }

    public WebView () {
        var setts = new WebKit.Settings ();
        setts.allow_modal_dialogs = false;
        setts.enable_fullscreen = false;
        setts.enable_html5_database = false;
        setts.enable_html5_local_storage = false;
        setts.enable_java = false;
        setts.enable_javascript = false;
        setts.enable_media_stream = false;
        setts.enable_offline_web_application_cache = false;
        setts.enable_page_cache = false;
        setts.enable_plugins = false;

        Object (settings: setts);
    }

    ~WebView () {
        cancellable.cancel ();
    }

    private void on_load_changed (WebKit.LoadEvent event) {
        if (event == WebKit.LoadEvent.FINISHED || event == WebKit.LoadEvent.COMMITTED) {
            update_height ();
        }

        if (event == WebKit.LoadEvent.FINISHED) {
            loaded = true;
            if (queued_body_content != null) {
                set_body_content ((owned) queued_body_content);
            }
            if (queued_signature_content != null) {
                set_signature_content ((owned) queued_signature_content);
            }
            if (queued_quote_content != null) {
                set_quote_content ((owned) queued_quote_content);
            }
            if (queued_body_html != null) {
                set_message_html ((owned) queued_body_html);
            }

            if (queued_load_images) {
                load_images ();
            }

            load_finished ();
        }
    }

    private void update_height () {
        if (is_composer) {
            return;
        }

        var message = new WebKit.UserMessage ("get-page-height", null);
        send_message_to_page.begin (message, cancellable, (obj, res) => {
            try {
                var response = send_message_to_page.end (res);
                height_request = response.parameters.get_int32 ();
            } catch (Error e) {
                // We can cancel the operation
                if (!(e is GLib.IOError.CANCELLED)) {
                    critical (e.message);
                }
            }
        });
    }

    public new void load_html (string? body) {
        base.load_html (body, INTERNAL_URL_BODY);
    }

    public void set_body_content (owned string content) {
        if (loaded) {
            var message = new WebKit.UserMessage ("set-body-content", new Variant.take_string ((owned) content));
            send_message_to_page.begin (message, cancellable);
        } else {
            queued_body_content = (owned) content;
        }
    }

    public void set_signature_content (owned string content) {
        if (loaded) {
            var message = new WebKit.UserMessage ("set-signature-content", new Variant.take_string ((owned) content));
            send_message_to_page.begin (message, cancellable);
        } else {
            queued_signature_content = (owned) content;
        }
    }

    public void set_quote_content (owned string content) {
        if (loaded) {
            var message = new WebKit.UserMessage ("set-quote-content", new Variant.take_string ((owned) content));
            send_message_to_page.begin (message, cancellable);
        } else {
            queued_quote_content = (owned) content;
        }
    }

    public async string? get_selected_text () {
        try {
            var message = new WebKit.UserMessage ("get-selected-text", null);
            var response = yield send_message_to_page (message, cancellable);
            return response.parameters.get_string ();
        } catch (Error e) {
            // We can cancel the operation
            if (!(e is GLib.IOError.CANCELLED)) {
                critical (e.message);
            }
        }

        return null;
    }

    private bool on_decide_policy (WebKit.WebView view, WebKit.PolicyDecision policy, WebKit.PolicyDecisionType type) {
        if (type == WebKit.PolicyDecisionType.NAVIGATION_ACTION ||
            type == WebKit.PolicyDecisionType.NEW_WINDOW_ACTION) {
            var nav_policy = (WebKit.NavigationPolicyDecision) policy;
            if (nav_policy.navigation_action.get_navigation_type () == WebKit.NavigationType.LINK_CLICKED) {
                link_activated (nav_policy.navigation_action.get_request ().uri);
            } else if (nav_policy.navigation_action.get_navigation_type () == WebKit.NavigationType.OTHER) {
                if (nav_policy.navigation_action.get_request ().uri == INTERNAL_URL_BODY) {
                    policy.use ();
                    return Gdk.EVENT_STOP;
                }
            }
        }

        policy.ignore ();
        return Gdk.EVENT_STOP;
    }

    public void add_internal_resource (string name, InputStream data) {
        internal_resources[name] = data;
    }

    public void load_images () {
        if (loaded) {
            var message = new WebKit.UserMessage ("set-image-loading-enabled", new Variant.boolean (true));
            send_message_to_page.begin (message, cancellable);
        } else {
            queued_load_images = true;
        }
    }

    public void execute_editor_command (string command, string argument = "") {
        var message = new WebKit.UserMessage ("execute-editor-command", new Variant ("(ss)", command, argument));
        send_message_to_page.begin (message, cancellable);
        body_html_changed = true;
    }

    public async bool query_command_state (string command) {
        try {
            var message = new WebKit.UserMessage ("query-command-state", new Variant.string (command));
            var response = yield send_message_to_page (message, cancellable);
            return response.parameters.get_boolean ();
        } catch (Error e) {
            // We can cancel the operation
            if (!(e is GLib.IOError.CANCELLED)) {
                critical (e.message);
            }
        }

        return false;
    }

    public async string? get_message_html (bool clean_for_sending = false) {
        string? message_html = null;

        if (!loaded && !cancellable.is_cancelled ()) {
            load_finished.connect (() => {
                get_message_html.begin (clean_for_sending, (obj, res) => {
                    message_html = get_message_html.end (res);
                    get_message_html.callback ();
                });
            });

            // this yield forces vala to wait until
            // get_body_html.callback () is called.
            // This is done by the above load_finished
            // event handler. The very same handler sets
            // the body_html variable before the callback
            // is called. To sum up: Once the callback is
            // called, the code proceeds execution
            // below this yield statement - and by this
            // time the body_html string is set correctly.
            yield;
        } else {
            try {
                var message = new WebKit.UserMessage ("get-message-html", new Variant.boolean (clean_for_sending));
                var response = yield send_message_to_page (message, cancellable);
                message_html = response.parameters.get_string ();
            } catch (Error e) {
                // We can cancel the operation
                if (!(e is GLib.IOError.CANCELLED)) {
                    critical (e.message);
                }
            }
        }

        return message_html;
    }

    public void set_message_html (owned string message_html) {
        if (!message_html.contains ("message-body")) {
            //We have to asume the message wasn't created using the elementary mail composer
            //and therefore doesn't have tags with the necessary ids
            set_body_content (message_html);
            return;
        }

        if (loaded) {
            var message = new WebKit.UserMessage ("set-message-html", new Variant.take_string ((owned) message_html));
            send_message_to_page.begin (message, cancellable);
        } else {
            queued_body_html = (owned) message_html;
        }
    }

    private void handle_cid_request (WebKit.URISchemeRequest request) {
        if (!handle_internal_response (request)) {
            request.finish_error (new FileError.NOENT ("Unknown CID"));
        }
    }

    private bool handle_internal_response (WebKit.URISchemeRequest request) {
#if HAS_SOUP_3
        string name = GLib.Uri.unescape_string (request.get_path ());
#else
        string name = Soup.URI.decode (request.get_path ());
#endif
        InputStream? buf = this.internal_resources[name];
        if (buf != null) {
            request.finish (buf, -1, null);
            return true;
        }

        return false;
    }

    public override bool user_message_received (WebKit.UserMessage message) {
        switch (message.name) {
            case "image-load-blocked":
                if (!queued_load_images) {
                    image_load_blocked ();
                }

                return true;
            case "selection-changed":
                selection_changed ();
                return true;
            default:
                critical ("Unhandled message: %s", message.name);
                break;
        }

        return false;
    }
}
