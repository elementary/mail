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

public class Mail.WelcomeView : Gtk.Box {
    construct {
        var headerbar = new Gtk.HeaderBar ();
        headerbar.add_css_class (Granite.STYLE_CLASS_FLAT);

        var welcome_icon = new Gtk.Image () {
            icon_name = "io.elementary.mail",
            margin_bottom = 6,
            margin_end = 12,
            pixel_size = 64
        };

        var welcome_badge = new Gtk.Image.from_icon_name ("preferences-desktop-online-accounts") {
            halign = valign = Gtk.Align.END,
        };

        var welcome_overlay = new Gtk.Overlay () {
            halign = Gtk.Align.CENTER,
            child = welcome_icon
        };
        welcome_overlay.add_overlay (welcome_badge);

        var welcome_title = new Gtk.Label (_("Connect an Account")) {
            max_width_chars = 70,
            wrap = true,
            xalign = 0
        };
        welcome_title.add_css_class (Granite.STYLE_CLASS_H1_LABEL);

        var welcome_description = new Gtk.Label (_("Mail uses email accounts configured in System Settings.")) {
            max_width_chars = 70,
            wrap = true,
            xalign = 0
        };
        welcome_description.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        var welcome_button = new Gtk.Button.with_label (_("Online Accounts…")) {
            margin_top = 24
        };
        welcome_button.add_css_class (Granite.STYLE_CLASS_SUGGESTED_ACTION);

        var grid = new Gtk.Grid () {
            column_spacing = 12,
            halign = valign = Gtk.Align.CENTER,
            hexpand = true,
            vexpand = true
        };
        grid.attach (welcome_overlay, 0, 0, 1, 2);
        grid.attach (welcome_title, 1, 0);
        grid.attach (welcome_description, 1, 1);
        grid.attach (welcome_button, 1, 2);

        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_box.append (headerbar);
        main_box.append (grid);

        var window_handle = new Gtk.WindowHandle () {
            child = main_box,
            hexpand = vexpand = true
        };

        append (window_handle);

        welcome_button.clicked.connect (() => {
            try {
                Gtk.show_uri ((Gtk.Window) get_root (), "settings://accounts/online", Gdk.CURRENT_TIME);
            } catch (Error e) {
                critical (e.message);
            }
        });
    }
}
