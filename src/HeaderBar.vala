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

    public HeaderBar () {
        Object (show_close_button: true,
                custom_title: new Gtk.Grid ());
    }

    construct {
        var application_instance = (Gtk.Application) GLib.Application.get_default ();

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

        var archive_button = new Gtk.Button.from_icon_name ("mail-archive", Gtk.IconSize.LARGE_TOOLBAR);
        archive_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_ARCHIVE;
        archive_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (archive_button.action_name),
            _("Move conversations to archive")
        );

        var trash_button = new Gtk.Button.from_icon_name ("edit-delete", Gtk.IconSize.LARGE_TOOLBAR);
        trash_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MOVE_TO_TRASH;
        trash_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (trash_button.action_name),
            _("Move conversations to Trash")
        );

        pack_start (reply_button);
        pack_start (reply_all_button);
        pack_start (forward_button);
        pack_end (trash_button);
        pack_end (archive_button);
        pack_end (mark_button);

        bind_property ("can-mark", mark_button, "sensitive");
    }
}
