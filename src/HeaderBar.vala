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

public class Mail.HeaderBar : Gtk.HeaderBar {
    public Gtk.Grid paned_start_grid { get; construct; }
    public Gtk.SearchEntry search_entry { get; construct; }

    public HeaderBar () {
        Object (show_close_button: true);
    }

    construct {
        var compose_button = new Gtk.Button.from_icon_name ("mail-message-new", Gtk.IconSize.LARGE_TOOLBAR);
        compose_button.halign = Gtk.Align.START;
        compose_button.tooltip_text = _("Compose new message (Ctrl+N, N)");
        compose_button.action_name = "win." + MainWindow.ACTION_COMPOSE_MESSAGE;

        search_entry = new Gtk.SearchEntry ();
        search_entry.placeholder_text = _("Search Mail");
        search_entry.valign = Gtk.Align.CENTER;

        paned_start_grid = new Gtk.Grid ();
        paned_start_grid.add (compose_button);

        var load_images_switch = new Gtk.Switch ();

        var load_images_grid = new Gtk.Grid ();
        load_images_grid.column_spacing = 6;
        load_images_grid.margin_end = 6;
        load_images_grid.margin_start = 3;
        load_images_grid.add (new Gtk.Label (_("Always Show Remote Images")));
        load_images_grid.add (load_images_switch);

        var load_images_menuitem = new Gtk.Button ();
        load_images_menuitem.get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);
        load_images_menuitem.add (load_images_grid);

        var account_settings_menuitem = new Gtk.ModelButton ();
        account_settings_menuitem.text = _("Account Settings…");

        var app_menu_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        app_menu_separator.margin_bottom = 3;
        app_menu_separator.margin_top = 3;

        var app_menu_grid = new Gtk.Grid ();
        app_menu_grid.margin_bottom = 3;
        app_menu_grid.margin_top = 3;
        app_menu_grid.orientation = Gtk.Orientation.VERTICAL;
        app_menu_grid.add (load_images_menuitem);
        app_menu_grid.add (app_menu_separator);
        app_menu_grid.add (account_settings_menuitem);
        app_menu_grid.show_all ();

        var app_menu = new Gtk.MenuButton ();
        var app_menu_popover = new Gtk.Popover (app_menu);
        app_menu_popover.add (app_menu_grid);
        app_menu.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
        app_menu.popover = app_menu_popover;

        pack_start (paned_start_grid);
        pack_start (search_entry);
        pack_end (app_menu);

        account_settings_menuitem.clicked.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://accounts/online", null);
            } catch (Error e) {
                warning ("Failed to open account settings: %s", e.message);
            }     
        });
    }
}
