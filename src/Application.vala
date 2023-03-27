/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017-2023 elementary, Inc. (https://elementary.io)
 */

public class Mail.Application : Gtk.Application {
    const OptionEntry[] OPTIONS = {
        { "background", 'b', 0, OptionArg.NONE, out run_in_background, "Run the Application in background", null},
        { null }
    };

    public static GLib.Settings settings;
    public static bool run_in_background;

    public Application () {
        Object (
            application_id: "io.elementary.mail",
            flags: ApplicationFlags.HANDLES_COMMAND_LINE
        );
    }

    static construct {
        settings = new GLib.Settings ("io.elementary.mail");
    }

    construct {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        add_main_option_entries (OPTIONS);
    }

    public override int command_line (ApplicationCommandLine command_line) {
        activate ();

        string[] argv = command_line.get_arguments ();
        var main_window = (MainWindow) active_window;

        // The only arguments we support are mailto: URLs passed in by the OS. See RFC 2368 for
        // details. We handle the most commonly used fields.
        foreach (var mailto_uri in argv[1:argv.length]) {
            string to = null;

            try {
#if HAS_SOUP_3
                GLib.Uri? mailto= null;
                try {
                    mailto = GLib.Uri.parse (mailto_uri, GLib.UriFlags.NONE);
                } catch (Error e) {
                    throw new OptionError.BAD_VALUE ("Argument is not a URL.");
                }

                if (mailto == null) {
                    throw new OptionError.BAD_VALUE ("Argument is not a URL.");
                }

                if (mailto.get_scheme () != "mailto") {
                    throw new OptionError.BAD_VALUE ("Cannot open non-mailto: URL");
                }

                to = GLib.Uri.unescape_string (mailto.get_path ());

                if (main_window.is_session_started) {
                    new ComposerWindow (main_window, to, mailto.get_query ()).show_all ();
                } else {
                    main_window.session_started.connect (() => {
                        new ComposerWindow (main_window, to, mailto.get_query ()).show_all ();
                    });
                }
#else
                Soup.URI mailto = new Soup.URI (mailto_uri);
                if (mailto == null) {
                    throw new OptionError.BAD_VALUE ("Argument is not a URL.");
                }

                if (mailto.scheme != "mailto") {
                    throw new OptionError.BAD_VALUE ("Cannot open non-mailto: URL");
                }

                to = Soup.URI.decode (mailto.path);

                if (main_window.is_session_started) {
                    new ComposerWindow (main_window, to, mailto.query).show_all ();
                } else {
                    main_window.session_started.connect (() => {
                        new ComposerWindow (main_window, to, mailto.query).show_all ();
                    });
                }
#endif
            } catch (OptionError e) {
                warning ("Argument parsing error. %s", e.message);
            }
        }

        return 0;
    }

    protected override void startup () {
        base.startup ();

        Hdy.init ();

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        Gtk.IconTheme.get_default ().add_resource_path ("/io/elementary/mail");

        var css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("io/elementary/mail/application.css");
        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            if (active_window != null) {
                active_window.destroy ();
            }
        });

        add_action (quit_action);
        set_accels_for_action ("app.quit", {"<Control>q"});
    }

    public override void activate () {
        if (run_in_background) {
            run_in_background = false;
            new InboxMonitor ().start.begin ();
            hold ();
            return;
        }

        if (active_window == null) {
            var main_window = new MainWindow (this);
            add_window (main_window);

            int window_x, window_y;
            var rect = Gtk.Allocation ();

            settings.get ("window-position", "(ii)", out window_x, out window_y);
            settings.get ("window-size", "(ii)", out rect.width, out rect.height);

            if (window_x != -1 || window_y != -1) {
                main_window.move (window_x, window_y);
            }

            main_window.set_allocation (rect);

            if (settings.get_boolean ("window-maximized")) {
                main_window.maximize ();
            }

            main_window.show_all ();
        }

        active_window.present ();
    }
}

public static int main (string[] args) {
    var application = new Mail.Application ();
    return application.run (args);
}
