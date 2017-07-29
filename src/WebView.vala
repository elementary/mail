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
    public signal void command_state_updated (string command, bool state);
    public signal void selection_changed ();

    private const string INTERNAL_URL_BODY = "elementary-mail:body";

    private int preferred_height = 0;
    private WebViewServer view_manager;
    private Gee.Map<string, InputStream> internal_resources;

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

        view_manager = WebViewServer.get_default ();
        view_manager.page_height_updated.connect ((page_id) => {
            if (page_id == get_page_id ()) {
                preferred_height = view_manager.get_height (page_id);
                queue_resize ();
            }
        });
        view_manager.image_load_blocked.connect ((page_id) => {
            if (page_id == get_page_id ()) {
                image_load_blocked ();
            }
        });
        view_manager.command_state_updated.connect ((page_id, command, state) => {
            if (page_id == get_page_id ()) {
                command_state_updated (command, state);
            }
        });
        view_manager.selection_changed.connect ((page_id) => {
            if (page_id == get_page_id ()) {
                selection_changed ();
            }
        });

        load_changed.connect (on_load_changed);
        decide_policy.connect (on_decide_policy);
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

    public void on_load_changed (WebKit.LoadEvent event) {
        if (event == WebKit.LoadEvent.FINISHED || event == WebKit.LoadEvent.COMMITTED) {
            view_manager.page_load_changed (get_page_id ());
        }
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        minimum_height = natural_height = preferred_height;
    }

    public new void load_html (string? body, string? base_uri = null) {
        base.load_html (body, base_uri ?? INTERNAL_URL_BODY);
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
        view_manager.set_load_images (get_page_id (), true);
    }

    public void execute_editor_command (string command) {
        view_manager.exec_command (get_page_id (), command);
    }

    public void query_command_state (string command) {
        view_manager.query_command_state (get_page_id (), command);
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
