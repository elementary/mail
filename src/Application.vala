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
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.Application : Gtk.Application {
    public static GLib.Settings settings;

    private MainWindow? main_window = null;

    public Application () {
        Object (
            application_id: "io.elementary.mail",
            flags: ApplicationFlags.HANDLES_OPEN
        );
    }

    static construct {
        settings = new GLib.Settings ("io.elementary.mail");
    }

    construct {
        Intl.setlocale (LocaleCategory.ALL, "");

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            if (main_window != null) {
                main_window.destroy ();
            }
        });

        add_action (quit_action);
        set_accels_for_action ("app.quit", {"<Control>q"});
    }

    public override void open (File[] files, string hint) {
        activate ();
    }

    public override void activate () {
        if (main_window == null) {
            main_window = new MainWindow ();

            int window_x, window_y;
            settings.get ("window-position", "(ii)", out window_x, out window_y);

            if (window_x != -1 ||  window_y != -1) {
                main_window.move (window_x, window_y);
            }

            int window_width, window_height;
            settings.get ("window-size", "(ii)", out window_width, out window_height);
            var rect = Gtk.Allocation ();
            rect.width = window_width;
            rect.height = window_height;
            main_window.set_allocation (rect);

            if (settings.get_boolean ("window-maximized")) {
                main_window.maximize ();
            }

            main_window.show_all ();
            add_window (main_window);

            var css_provider = new Gtk.CssProvider ();
            css_provider.load_from_resource ("io/elementary/mail/application.css");
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
    }
}

public static int main (string[] args) {
    var application = new Mail.Application ();
    return application.run (args);
}
