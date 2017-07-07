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
            main_window.show_all ();
            add_window (main_window);
        }
    }
}

public static int main (string[] args) {
    var application = new Mail.Application ();
    return application.run (args);
}
