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

public class Mail.WelcomeView : Gtk.Grid {
    construct {
        halign = valign = Gtk.Align.CENTER;
        orientation = Gtk.Orientation.VERTICAL;

        var welcome_icon = new Gtk.Image ();
        welcome_icon.icon_name = "internet-mail";
        welcome_icon.margin_bottom = 6;
        welcome_icon.margin_end = 12;
        welcome_icon.pixel_size = 64;

        var welcome_badge = new Gtk.Image.from_icon_name ("preferences-desktop-online-accounts", Gtk.IconSize.DIALOG);
        welcome_badge.halign = welcome_badge.valign = Gtk.Align.END;

        var welcome_overlay = new Gtk.Overlay ();
        welcome_overlay.halign = Gtk.Align.CENTER;
        welcome_overlay.add (welcome_icon);
        welcome_overlay.add_overlay (welcome_badge);

        var welcome_title = new Gtk.Label (_("Connect an Account"));
        welcome_title.wrap = true;
        welcome_title.max_width_chars = 70;
        welcome_title.get_style_context ().add_class (Granite.STYLE_CLASS_H1_LABEL);

        var welcome_description = new Gtk.Label (_("Mail uses email accounts configured in System Settings."));
        welcome_description.wrap = true;
        welcome_description.max_width_chars = 70;
        welcome_description.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        var welcome_button = new Gtk.Button.with_label (_("Online Accounts…"));
        weak Gtk.StyleContext welcome_button_style_context = welcome_button.get_style_context ();
        welcome_button.halign = Gtk.Align.CENTER;
        welcome_button.margin_top = 24;
        welcome_button_style_context.add_class (Granite.STYLE_CLASS_H3_LABEL);
        welcome_button_style_context.add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        add (welcome_overlay);
        add (welcome_title);
        add (welcome_description);
        add (welcome_button);

        welcome_button.clicked.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://accounts/online", null);
            } catch (Error e) {
                critical (e.message);
            }
        });

        show_all ();
    }
}
