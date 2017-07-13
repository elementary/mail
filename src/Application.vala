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

    construct {
        application_id = "io.elementary.mail";
        flags |= ApplicationFlags.HANDLES_OPEN;
        Intl.setlocale (LocaleCategory.ALL, "");

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            if (main_window != null) {
                main_window.destroy ();
            }
        });

        add_action (quit_action);
        add_accelerator ("<Control>q", "app.quit", null);
    }

    public override void open (File[] files, string hint) {
        activate ();
    }

    public override void activate () {
        if (main_window == null) {
            main_window = new MainWindow ();

            var settings = new GLib.Settings ("io.elementary.mail");

            var window_height = settings.get_int ("window-height");
            var window_width = settings.get_int ("window-width");
            var window_x = settings.get_int ("window-x");
            var window_y = settings.get_int ("window-y");

            if (window_x != -1 ||  window_y != -1) {
                main_window.move (window_x, window_y);
            }

            if (window_height != -1 ||  window_width != -1) {
                var rect = Gtk.Allocation ();
                rect.height = window_height;
                rect.width = window_width;
                main_window.set_allocation (rect);
            }

            main_window.show_all ();
            add_window (main_window);

            main_window.size_allocate.connect (() => {
                Gtk.Allocation rect;
                main_window.get_allocation (out rect);
                settings.set_int ("window-height", rect.height);
                settings.set_int ("window-width", rect.width);
            });

            main_window.state_changed.connect (() => {
                int root_x, root_y;
                main_window.get_position (out root_x, out root_y);
                settings.set_int ("window-x", root_x);
                settings.set_int ("window-y", root_y);
            });
        }
    }
}

public static int main (string[] args) {
    var application = new Mail.Application ();
    return application.run (args);
}
