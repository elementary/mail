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
    private MainWindow? main_window = null;

    public Application () {
        Object (
            application_id: "io.elementary.mail",
            flags: ApplicationFlags.HANDLES_OPEN
        );
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

            var settings = new GLib.Settings ("io.elementary.mail");

            var window_position = settings.get_value ("window-position");
            var window_x = (int32) window_position.get_child_value (0);
            var window_y = (int32) window_position.get_child_value (1);

            if (window_x != -1 ||  window_y != -1) {
                main_window.move (window_x, window_y);
            }

            var window_size = settings.get_value ("window-size");
            var rect = Gtk.Allocation ();
            rect.height = (int32) window_size.get_child_value (1);;
            rect.width = (int32) window_size.get_child_value (0);
            main_window.set_allocation (rect);

            if (settings.get_boolean ("window-maximized")) {
                main_window.maximize ();
            }

            main_window.show_all ();
            add_window (main_window);

            var css_provider = new Gtk.CssProvider ();
            css_provider.load_from_resource ("io/elementary/mail/application.css");
            Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            main_window.delete_event.connect (() => {
                if (main_window.is_maximized) {
                    settings.set_boolean ("window-maximized", true);
                } else {
                    settings.set_boolean ("window-maximized", false);

                    main_window.get_allocation (out rect);
                    settings.set_value ("window-size", new int[] { rect.width, rect.height });

                    int root_x, root_y;
                    main_window.get_position (out root_x, out root_y);
                    settings.set_value ("window-position", new int[] { root_x, root_y });
                }
                return false;
            });
        }
    }
}

public static int main (string[] args) {
    var application = new Mail.Application ();
    return application.run (args);
}
