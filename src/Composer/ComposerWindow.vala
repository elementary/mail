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

    public ComposerWindow () {
        Object (
            height_request: 600,
            width_request: 680
        );
    }

    construct {
        var headerbar = new ComposerHeaderBar ();
        set_titlebar (headerbar);

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

        var content_grid = new Gtk.Grid ();
        content_grid.margin = 6;
        content_grid.margin_top = 12;
        content_grid.column_spacing = 6;
        content_grid.row_spacing = 6;
        content_grid.attach (to_label, 0, 0, 1, 1);
        content_grid.attach (to_val, 1, 0, 1, 1);
        content_grid.attach (cc_label, 0, 1, 1, 1);
        content_grid.attach (cc_val, 1, 1, 1, 1);
        content_grid.attach (subject_label, 0, 2, 1, 1);
        content_grid.attach (subject_val, 1, 2, 1, 1);
        add (content_grid);
    }
}
