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

namespace MailWebViewExtension {
    [DBus (name = "io.elementary.mail.WebViewServer")]
    public interface Server : Object {
        public abstract void set_image_loading_enabled (uint64 view, bool enabled) throws GLib.DBusError, GLib.IOError;
        public abstract void execute_command (uint64 view, string command, string argument) throws GLib.DBusError, GLib.IOError;
        public abstract bool query_command_state (uint64 view, string command) throws GLib.DBusError, GLib.IOError;
        public abstract int get_page_height (uint64 view) throws GLib.DBusError, GLib.IOError;
        public abstract string get_body_html (uint64 view) throws GLib.DBusError, GLib.IOError;
        public abstract void set_body_html (uint64 view, string html) throws GLib.DBusError, GLib.IOError;
        public abstract string get_selected_text (uint64 view) throws GLib.DBusError, GLib.IOError;

        public signal void selection_changed (uint64 view);
        public signal void image_load_blocked (uint64 view);
    }
}

public class Mail.WebView : WebKit.WebView {
    public signal void image_load_blocked ();
    public signal void link_activated (string url);
    public signal void selection_changed ();
    public signal void load_finished ();

    private const string INTERNAL_URL_BODY = "elementary-mail:body";
    private const string SERVER_BUS_NAME = "io.elementary.mail.WebViewServer";

    private int preferred_height = 0;
    private MailWebViewExtension.Server? extension = null;
    private uint watch_identifier = 0;
    private Gee.Map<string, InputStream> internal_resources;

    private bool ready = false;
    private bool loaded = false;
    private bool queued_load_images = false;
    private string? queued_content = null;
    private string? queued_body_content = null;

    static construct {
        weak WebKit.WebContext context = WebKit.WebContext.get_default ();
        unowned string? webkit_extension_path_env = Environment.get_variable ("WEBKIT_EXTENSION_PATH");
        context.set_web_extensions_directory (webkit_extension_path_env ?? WEBKIT_EXTENSION_PATH);

        context.register_uri_scheme ("cid", (req) => {
            WebView? view = req.get_web_view () as WebView;
            if (view != null) {
                view.handle_cid_request (req);
            }
        });
    }

    construct {
        expand = true;

        internal_resources = new Gee.HashMap<string, InputStream> ();

        watch_identifier = Bus.watch_name (BusType.SESSION, SERVER_BUS_NAME, BusNameWatcherFlags.NONE, on_server_appear);
        on_ready ();
    }

    public WebView () {
        var setts = new WebKit.Settings ();
        setts.allow_modal_dialogs = false;
        setts.enable_fullscreen = false;
        setts.enable_html5_database = false;
        setts.enable_html5_local_storage = false;
        setts.enable_java = false;
        setts.enable_javascript = true;
        setts.enable_media_stream = false;
        setts.enable_offline_web_application_cache = false;
        setts.enable_page_cache = false;
        setts.enable_plugins = false;
        setts.enable_developer_extras = true;

        Object (settings: setts);
    }

    private void on_server_appear (DBusConnection conn, string name, string owner) {
        try {
            extension = Bus.get_proxy_sync (BusType.SESSION, SERVER_BUS_NAME, "/io/elementary/mail/WebViewServer");
        } catch (IOError e) {
            warning ("Couldn't connect to WebKit extension DBus: %s", e.message);
        }

        /*
         * Stop waiting for the extension, to prevent this WebView from leaking
         * via the method reference given to Bus.watch_name.
         */
        Bus.unwatch_name (watch_identifier);

    }

    private void on_ready () {
        ready = true;

        if (extension != null) {
            extension.image_load_blocked.connect ((page_id) => {
                if (page_id == get_page_id ()) {
                    image_load_blocked ();
                }
            });
            extension.selection_changed.connect ((page_id) => {
                if (page_id == get_page_id ()) {
                    selection_changed ();
                }
            });
        }

        if (queued_load_images) {
            load_images ();
        }

        if (queued_content != null) {
            load_html (queued_content);
        }
    }

    public override void load_changed (WebKit.LoadEvent event) {
        if (event == WebKit.LoadEvent.FINISHED || event == WebKit.LoadEvent.COMMITTED) {
            run_javascript.begin ("document.documentElement.scrollHeight", null, (obj, res) => {
                try {
                    var r = run_javascript.end (res);
                    var val = r.get_js_value ();
                    if (val.is_number ()) {
                        preferred_height = val.to_int32 ();
                        queue_resize ();
                    }

                    unowned JSC.Exception? exception = val.get_context ().get_exception ();
                    if (exception != null) {
                        critical ("Failed to call: %s", exception.report ());
                    }
                } catch (Error e) {
                    critical ("%s", e.message);
                }
            });

            run_javascript.begin ("var tt = new MailWebExtensionHandler();", null, (obj, res) => {
                try {
                    var r = run_javascript.end (res);
                    var val = r.get_js_value ();

                    unowned JSC.Exception? exception = val.get_context ().get_exception ();
                    if (exception != null) {
                        critical ("Failed to call: %s", exception.report ());
                    } else {
                        critical (val.to_string ());
                    }
                } catch (Error e) {
                    critical ("%s", e.message);
                }
            });
        }

        if (event == WebKit.LoadEvent.FINISHED) {
            on_loaded ();
            load_finished ();
            get_inspector ().show ();
        }
    }

    private void on_loaded () {
        loaded = true;
        if (queued_body_content != null && ready) {
            set_body_content (queued_body_content);
        }
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        minimum_height = natural_height = preferred_height;
    }

    public new void load_html (string? body) {
        if (ready) {
            base.load_html (body, INTERNAL_URL_BODY);
        } else {
            queued_content = body;
        }
    }

    public void set_body_content (string content) {
        if (loaded) {
            try {
                extension.set_body_html (get_page_id (), content);
            } catch (Error e) {
                critical (e.message);
            }
        } else {
            queued_body_content = content;
        }
    }

    public string get_selected_text () {
        if (loaded) {
            try {
                return extension.get_selected_text (get_page_id ());
            } catch (Error e) {
                return "";
            }
        } else {
            return "";
        }
    }

    public override bool decide_policy (WebKit.PolicyDecision decision, WebKit.PolicyDecisionType type) {
        switch (type) {
            case WebKit.PolicyDecisionType.NAVIGATION_ACTION:
            case WebKit.PolicyDecisionType.NEW_WINDOW_ACTION:
                unowned WebKit.NavigationAction action = ((WebKit.NavigationPolicyDecision) decision).navigation_action;
                var nav_type = action.get_navigation_type ();
                switch (nav_type) {
                    case WebKit.NavigationType.LINK_CLICKED:
                        link_activated (action.get_request ().uri);
                        break;
                    case WebKit.NavigationType.OTHER:
                        if (action.get_request ().uri == INTERNAL_URL_BODY) {
                            decision.use ();
                            return Gdk.EVENT_STOP;
                        }

                        break;
                }
            break;
        }

        decision.ignore ();
        return Gdk.EVENT_STOP;
    }

    public void add_internal_resource (string name, InputStream data) {
        internal_resources[name] = data;
    }

    public void load_images () {
        if (ready) {
            try {
                extension.set_image_loading_enabled (get_page_id (), true);
            } catch (Error e) {
                critical (e.message);
            }
        } else {
            queued_load_images = true;
        }
    }

    public void execute_editor_command (string command, string argument = "") {
        try {
            extension.execute_command (get_page_id (), command, argument);
        } catch (Error e) {
            critical (e.message);
        }
    }

    public bool query_command_state (string command) {
        if (extension != null) {
            try {
                return extension.query_command_state (get_page_id (), command);
            } catch (Error e) {
                critical (e.message);
            }
        }

        return false;
    }

    public string? get_body_html () {
        if (extension != null) {
            try {
                return extension.get_body_html (get_page_id ());
            } catch (Error e) {
                critical (e.message);
            }
        }

        return null;
    }

    private void handle_cid_request (WebKit.URISchemeRequest request) {
        if (!handle_internal_response (request)) {
            request.finish_error (new FileError.NOENT ("Unknown CID"));
        }
    }

    private bool handle_internal_response (WebKit.URISchemeRequest request) {
        string name = Soup.URI.decode (request.get_path ());
        InputStream? buf = this.internal_resources[name];
        if (buf != null) {
            request.finish (buf, -1, null);
            return true;
        }

        return false;
    }
}
