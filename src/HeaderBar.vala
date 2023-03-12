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

public class Mail.HeaderBar : Gtk.HeaderBar {
    public bool can_mark { get; set; }

    public HeaderBar () {
        Object (show_close_button: true,
                custom_title: new Gtk.Grid ());
    }

    construct {
        var application_instance = (Gtk.Application) GLib.Application.get_default ();

        var load_images_menuitem = new Granite.SwitchModelButton (_("Always Show Remote Images"));

        var account_settings_menuitem = new Gtk.Button ();
        account_settings_menuitem.label = _("Account Settings…");

        var app_menu_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
            margin_bottom = 3,
            margin_top = 3
        };

        var app_menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_bottom = 3,
            margin_top = 3
        };
        app_menu_box.append (load_images_menuitem);
        app_menu_box.append (app_menu_separator);
        app_menu_box.append (account_settings_menuitem);

        var app_menu_popover = new Gtk.Popover ();
        app_menu_popover.set_child (app_menu_box);

        var app_menu = new Gtk.MenuButton () {
            icon_name = "open-menu",
            popover = app_menu_popover,
            tooltip_text = _("Menu")
        };

        var reply_button = new Gtk.Button.from_icon_name ("mail-reply-sender");
        reply_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REPLY;
        reply_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (reply_button.action_name),
            _("Reply")
        );

        var reply_all_button = new Gtk.Button.from_icon_name ("mail-reply-all");
        reply_all_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REPLY_ALL;
        reply_all_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (reply_all_button.action_name),
            _("Reply All")
        );

        var forward_button = new Gtk.Button.from_icon_name ("mail-forward");
        forward_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_FORWARD;
        forward_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (forward_button.action_name),
            _("Forward")
        );

        //@TODO: check whether this menu implementation works: (this is the old code, below the new one (without items))
        // var mark_unread_item = new MenuItem ();
        // mark_unread_item.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNREAD;
        // mark_unread_item.bind_property ("sensitive", mark_unread_item, "visible");
        // mark_unread_item.add (new Granite.AccelLabel.from_action_name (_("Mark as Unread"), mark_unread_item.action_name));

        // var mark_read_item = new MenuItem ();
        // mark_read_item.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_READ;
        // mark_read_item.bind_property ("sensitive", mark_read_item, "visible");
        // mark_read_item.add (new Granite.AccelLabel.from_action_name (_("Mark as Read"), mark_read_item.action_name));

        // var mark_star_item = new MenuItem ();
        // mark_star_item.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_STAR;
        // mark_star_item.bind_property ("sensitive", mark_star_item, "visible");
        // mark_star_item.add (new Granite.AccelLabel.from_action_name (_("Star"), mark_star_item.action_name));

        // var mark_unstar_item = new MenuItem ();
        // mark_unstar_item.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNSTAR;
        // mark_unstar_item.bind_property ("sensitive", mark_unstar_item, "visible");
        // mark_unstar_item.add (new Granite.AccelLabel.from_action_name (_("Unstar"), mark_unstar_item.action_name));

        var mark_menu_model = new Menu();
        mark_menu_model.append (_("Mark as Unread"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNREAD);
        mark_menu_model.append (_("Mark as Read"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_READ);
        mark_menu_model.append (_("Star"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_STAR);
        mark_menu_model.append (_("Unstar"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNSTAR);

        var mark_menu = new Gtk.PopoverMenu.from_model (mark_menu_model);

        var mark_button = new Gtk.MenuButton () {
            icon_name = "edit-mark",
            popover = mark_menu,
            tooltip_text = _("Mark Conversation")
        };

        var archive_button = new Gtk.Button.from_icon_name ("mail-archive");
        archive_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ARCHIVE;
        archive_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (archive_button.action_name),
            _("Move conversations to archive")
        );

        var trash_button = new Gtk.Button.from_icon_name ("edit-delete");
        trash_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MOVE_TO_TRASH;
        trash_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (trash_button.action_name),
            _("Move conversations to Trash")
        );

        pack_start (reply_button);
        pack_start (reply_all_button);
        pack_start (forward_button);
        pack_start (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        pack_start (mark_button);
        pack_start (archive_button);
        pack_start (trash_button);
        pack_end (app_menu);

        bind_property ("can-mark", mark_button, "sensitive");

        var settings = new GLib.Settings ("io.elementary.mail");
        settings.bind ("always-load-remote-images", load_images_menuitem, "active", SettingsBindFlags.DEFAULT);

        account_settings_menuitem.clicked.connect (() => {
            try {
                AppInfo.launch_default_for_uri ("settings://accounts/online", null);
            } catch (Error e) {
                warning ("Failed to open account settings: %s", e.message);
            }
        });
    }
}
