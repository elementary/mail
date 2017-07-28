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
    public ComposerWindow (Gtk.Window parent) {
        Object (
            height_request: 600,
            title: _("New Message"),
            transient_for: parent,
            width_request: 680,
            window_position: Gtk.WindowPosition.CENTER_ON_PARENT
        );
    }

    construct {
        var to_label = new Gtk.Label (_("To:"));
        to_label.halign = Gtk.Align.END;
        to_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var cc_label = new Gtk.Label (_("Cc:"));
        cc_label.halign = Gtk.Align.END;
        cc_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var subject_label = new Gtk.Label (_("Subject:"));
        subject_label.halign = Gtk.Align.END;
        subject_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var to_val = new Gtk.Entry ();
        to_val.hexpand = true;

        var cc_val = new Gtk.Entry ();
        cc_val.hexpand = true;

        var subject_val = new Gtk.Entry ();
        subject_val.hexpand = true;

        var recipient_grid = new Gtk.Grid ();
        recipient_grid.margin = 6;
        recipient_grid.margin_top = 12;
        recipient_grid.column_spacing = 6;
        recipient_grid.row_spacing = 6;
        recipient_grid.attach (to_label, 0, 0, 1, 1);
        recipient_grid.attach (to_val, 1, 0, 1, 1);
        recipient_grid.attach (cc_label, 0, 1, 1, 1);
        recipient_grid.attach (cc_val, 1, 1, 1, 1);
        recipient_grid.attach (subject_label, 0, 2, 1, 1);
        recipient_grid.attach (subject_val, 1, 2, 1, 1);

        var actions = new ComposerWindowActions ();
        var composer_widget = new ComposerWidget (actions);

        var content_grid = new Gtk.Grid ();
        content_grid.orientation = Gtk.Orientation.VERTICAL;
        content_grid.add (recipient_grid);
        content_grid.add (composer_widget);
        content_grid.add (actions.container);

        get_style_context ().add_class ("rounded");
        add (content_grid);

        to_val.changed.connect (() => {
            composer_widget.has_recipients = to_val.text != "";
        });
    }
}
