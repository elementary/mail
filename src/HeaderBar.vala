/*-
 * Copyright 2017-2020 elementary, Inc. (https://elementary.io)
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

public class Mail.HeaderBar : Hdy.HeaderBar {
    public bool can_mark { get; set; }
    public bool can_search { get; set; }
    public Gtk.SearchEntry search_entry { get; construct; }
    private Gtk.Grid spacing_widget;

    public HeaderBar () {
        Object (show_close_button: true,
                custom_title: new Gtk.Grid ());
    }

    construct {
        var application_instance = (Gtk.Application) GLib.Application.get_default ();

        var compose_button = new Gtk.Button.from_icon_name ("mail-message-new", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_COMPOSE_MESSAGE,
            halign = Gtk.Align.START
        };
        compose_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (compose_button.action_name),
            _("Compose new message")
        );

        spacing_widget = new Gtk.Grid ();

        search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Search Mail"),
            valign = Gtk.Align.CENTER
        };

        var load_images_switch = new Gtk.Switch ();

        var settings = new GLib.Settings ("io.elementary.mail");
        settings.bind ("always-load-remote-images", load_images_switch, "active", SettingsBindFlags.DEFAULT);

        var load_images_grid = new Gtk.Grid ();
        load_images_grid.column_spacing = 12;
        load_images_grid.add (new Gtk.Label (_("Always Show Remote Images")));
        load_images_grid.add (load_images_switch);

        var load_images_menuitem = new Gtk.ModelButton ();
        load_images_menuitem.get_child ().destroy ();
        load_images_menuitem.add (load_images_grid);

        var account_settings_menuitem = new Gtk.ModelButton ();
        account_settings_menuitem.text = _("Account Settings…");

        var app_menu_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
            margin_bottom = 3,
            margin_top = 3
        };

        var app_menu_grid = new Gtk.Grid () {
            margin_bottom = 3,
            margin_top = 3,
            orientation = Gtk.Orientation.VERTICAL
        };
        app_menu_grid.add (load_images_menuitem);
        app_menu_grid.add (app_menu_separator);
        app_menu_grid.add (account_settings_menuitem);
        app_menu_grid.show_all ();

        var app_menu_popover = new Gtk.Popover (null);
        app_menu_popover.add (app_menu_grid);

        var app_menu = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR),
            popover = app_menu_popover,
            tooltip_text = _("Menu")
        };

        var reply_button = new Gtk.Button.from_icon_name ("mail-reply-sender", Gtk.IconSize.LARGE_TOOLBAR);
        reply_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REPLY;
        reply_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (reply_button.action_name),
            _("Reply")
        );

        var reply_all_button = new Gtk.Button.from_icon_name ("mail-reply-all", Gtk.IconSize.LARGE_TOOLBAR);
        reply_all_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REPLY_ALL;
        reply_all_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (reply_all_button.action_name),
            _("Reply All")
        );

        var forward_button = new Gtk.Button.from_icon_name ("mail-forward", Gtk.IconSize.LARGE_TOOLBAR);
        forward_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_FORWARD;
        forward_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (forward_button.action_name),
            _("Forward")
        );

        var mark_unread_item = new Gtk.MenuItem ();
        mark_unread_item.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNREAD;
        mark_unread_item.bind_property ("sensitive", mark_unread_item, "visible");
        mark_unread_item.add (new Granite.AccelLabel.from_action_name (_("Mark as Unread"), mark_unread_item.action_name));

        var mark_read_item = new Gtk.MenuItem ();
        mark_read_item.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_READ;
        mark_read_item.bind_property ("sensitive", mark_read_item, "visible");
        mark_read_item.add (new Granite.AccelLabel.from_action_name (_("Mark as Read"), mark_read_item.action_name));

        var mark_star_item = new Gtk.MenuItem ();
        mark_star_item.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_STAR;
        mark_star_item.bind_property ("sensitive", mark_star_item, "visible");
        mark_star_item.add (new Granite.AccelLabel.from_action_name (_("Star"), mark_star_item.action_name));

        var mark_unstar_item = new Gtk.MenuItem ();
        mark_unstar_item.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNSTAR;
        mark_unstar_item.bind_property ("sensitive", mark_unstar_item, "visible");
        mark_unstar_item.add (new Granite.AccelLabel.from_action_name (_("Unstar"), mark_unstar_item.action_name));

        var mark_menu = new Gtk.Menu ();
        mark_menu.add (mark_unread_item);
        mark_menu.add (mark_read_item);
        mark_menu.add (mark_star_item);
        mark_menu.add (mark_unstar_item);
        mark_menu.show_all ();

        var mark_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("edit-mark", Gtk.IconSize.LARGE_TOOLBAR),
            popup = mark_menu,
            tooltip_text = _("Mark Conversation")
        };

        var trash_button = new Gtk.Button.from_icon_name ("edit-delete", Gtk.IconSize.LARGE_TOOLBAR);
        trash_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MOVE_TO_TRASH;
        trash_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (trash_button.action_name),
            _("Move conversations to Trash")
        );

        pack_start (compose_button);
        pack_start (spacing_widget);
        pack_start (search_entry);
        pack_start (reply_button);
        pack_start (reply_all_button);
        pack_start (forward_button);
        pack_start (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        pack_start (mark_button);
        pack_start (trash_button);
        pack_end (app_menu);

        bind_property ("can-mark", mark_button, "sensitive");
        bind_property ("can-search", search_entry, "sensitive", BindingFlags.SYNC_CREATE);

        account_settings_menuitem.clicked.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://accounts/online", null);
            } catch (Error e) {
                warning ("Failed to open account settings: %s", e.message);
            }
        });

        load_images_menuitem.button_release_event.connect (() => {
            load_images_switch.activate ();
            return Gdk.EVENT_STOP;
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
