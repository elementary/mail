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
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public class Mail.ComposerWindow : Gtk.ApplicationWindow {
    public string? to { get; construct; default = null; }
    public string? cc { get; construct; default = null; }
    public string? subject { get; construct; default = null; }

    public ComposerWindow (Gtk.Window parent) {
        Object (transient_for: parent);
    }

    public ComposerWindow.with_headers (Gtk.Window parent, string? to, string? cc, string? subject) {
        Object (
            transient_for: parent,
            to: to,
            cc: cc,
            subject: subject
        );
    }

    construct {
        var composer_widget = new ComposerWidget.with_headers (to, cc, subject);
        composer_widget.discarded.connect (() => {
            close ();
        });
        composer_widget.sent.connect (() => {
            close ();
        });

        var content_grid = new Gtk.Grid ();
        content_grid.orientation = Gtk.Orientation.VERTICAL;
        content_grid.add (composer_widget);

        height_request = 600;
        width_request = 680;
        window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
        title = _("New Message");
        get_style_context ().add_class ("rounded");
        add (content_grid);
    }
}
