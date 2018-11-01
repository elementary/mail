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
    public Gtk.SearchEntry search_entry { get; construct; }
    private Gtk.Grid spacing_widget;

    public HeaderBar () {
        Object (show_close_button: true,
                custom_title: new Gtk.Grid ());
    }

    construct {
        var compose_button = new Gtk.Button.from_icon_name ("mail-message-new", Gtk.IconSize.LARGE_TOOLBAR);
        compose_button.halign = Gtk.Align.START;
        compose_button.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>N"}, _("Compose new message"));
        compose_button.action_name = "win." + MainWindow.ACTION_COMPOSE_MESSAGE;

        spacing_widget = new Gtk.Grid ();

        search_entry = new Gtk.SearchEntry ();
        search_entry.placeholder_text = _("Search Mail");
        search_entry.valign = Gtk.Align.CENTER;

        var load_images_switch = new Gtk.Switch ();

        var settings = new GLib.Settings ("io.elementary.mail");
        settings.bind ("always-load-remote-images", load_images_switch, "active", SettingsBindFlags.DEFAULT);

        var load_images_grid = new Gtk.Grid ();
        load_images_grid.column_spacing = 12;
        load_images_grid.margin_end = 6;
        load_images_grid.margin_start = 6;
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
        app_menu.tooltip_text = _("Menu");

        var reply_button = new Gtk.Button.from_icon_name ("mail-reply-sender", Gtk.IconSize.LARGE_TOOLBAR);
        reply_button.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>R"}, _("Reply"));
        reply_button.action_name = "win." + MainWindow.ACTION_REPLY;

        var reply_all_button = new Gtk.Button.from_icon_name ("mail-reply-all", Gtk.IconSize.LARGE_TOOLBAR);
        reply_all_button.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl><Shift>R"}, _("Reply All"));
        reply_all_button.action_name = "win." + MainWindow.ACTION_REPLY_ALL;

        var forward_button = new Gtk.Button.from_icon_name ("mail-forward", Gtk.IconSize.LARGE_TOOLBAR);
        forward_button.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl><Shift>F"}, _("Forward"));
        forward_button.action_name = "win." + MainWindow.ACTION_FORWARD;

        var trash_button = new Gtk.Button.from_icon_name ("edit-delete", Gtk.IconSize.LARGE_TOOLBAR);
        trash_button.tooltip_markup = Granite.markup_accel_tooltip ({"Delete", "BackSpace"}, _("Move conversations to Trash"));
        trash_button.action_name = "win." + MainWindow.ACTION_MOVE_TO_TRASH;

        pack_start (compose_button);
        pack_start (spacing_widget);
        pack_start (search_entry);
        pack_start (reply_button);
        pack_start (reply_all_button);
        pack_start (forward_button);
        pack_start (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        pack_start (trash_button);
        pack_end (app_menu);

        account_settings_menuitem.clicked.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://accounts/online", null);
            } catch (Error e) {
                warning ("Failed to open account settings: %s", e.message);
            }
        });

        load_images_menuitem.clicked.connect (() => {
            load_images_switch.activate ();
        });
    }

    public void set_paned_positions (int start_position, int end_position, bool start_changed = true) {
        search_entry.width_request = end_position - start_position + 1;
        if (start_changed) {
            int spacing_position;
            child_get (spacing_widget, "position", out spacing_position, null);
            var style_context = get_style_context ();
            // The left padding between the window and the headerbar widget
            int offset = style_context.get_padding (style_context.get_state ()).left;
            forall ((widget) => {
                if (widget == custom_title || widget.get_style_context ().has_class ("right")) {
                    return;
                }

                int widget_position;
                child_get (widget, "position", out widget_position, null);
                if (widget_position < spacing_position) {
                    offset += widget.get_allocated_width () + spacing;
                }
            });

            offset += spacing;
            spacing_widget.width_request = start_position - int.min (offset, start_position);
        }
    }
}
