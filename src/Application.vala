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

        MainWindow? main_window = null;
        foreach (unowned var window in get_windows ()) {
            if (window is MainWindow) {
                main_window = (MainWindow) window;
                break;
            }
        }

        // The only arguments we support are mailto: URLs passed in by the OS. See RFC 2368 for
        // details. We handle the most commonly used fields.
        foreach (var mailto_uri in argv[1:argv.length]) {
            string to = null;

            try {
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
                    new Composer (to, mailto.get_query ()).present ();
                } else {
                    main_window.session_started.connect (() => {
                        new Composer (to, mailto.get_query ()).present ();
                    });
                }
            } catch (OptionError e) {
                warning ("Argument parsing error. %s", e.message);
            }
        }

        return 0;
    }

    protected override void startup () {
        base.startup ();

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        var css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("io/elementary/mail/application.css");
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            foreach (unowned var window in get_windows ()) {
                if (window is MainWindow) {
                    window.destroy ();
                    break;
                }
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

        MainWindow? main_window = null;
        foreach (unowned var window in get_windows ()) {
            if (window is MainWindow) {
                main_window = (MainWindow) window;
                break;
            }
        }

        if (main_window == null) {
            main_window = new MainWindow (this);
            add_window (main_window);
        }

        main_window.present ();
    }
}

public static int main (string[] args) {
    var application = new Mail.Application ();
    return application.run (args);
}
