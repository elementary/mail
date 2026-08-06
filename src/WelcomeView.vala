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

public class Mail.WelcomeView : Granite.Bin {
    construct {
        var headerbar = new Adw.HeaderBar () {
            // show_start_title_buttons = true
        };
        headerbar.add_css_class (Granite.STYLE_CLASS_FLAT);

        var placeholder = new Granite.Placeholder (_("Connect an Account")) {
            description = _("Mail uses email accounts configured in System Settings."),
            icon = new ThemedIcon ("io.elementary.mail")
        };

        var welcome_button = placeholder.append_button (new ThemedIcon ("preferences-desktop-online-accounts"), _("Online Accounts…"), "");
        welcome_button.add_css_class (Granite.CssClass.SUGGESTED);

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_box.append (headerbar);
        main_box.append (placeholder);

        var window_handle = new Gtk.WindowHandle () {
            child = main_box
        };

        child = window_handle;

        welcome_button.clicked.connect (() => {
            try {
                Gtk.show_uri_on_window ((Gtk.Window) get_root (), "settings://accounts/online", Gdk.CURRENT_TIME);
            } catch (Error e) {
                critical (e.message);
            }
        });
    }
}
