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
        to_label.xalign = 1;
        to_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var subject_label = new Gtk.Label (_("Subject:"));
        subject_label.xalign = 1;
        subject_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var to_val = new Gtk.Entry ();
        to_val.hexpand = true;

        var cc_button = new Gtk.ToggleButton.with_label (_("Cc"));

        var bcc_button = new Gtk.ToggleButton.with_label (_("Bcc"));

        var to_grid = new Gtk.Grid ();
        to_grid.add (to_val);
        to_grid.add (cc_button);
        to_grid.add (bcc_button);

        var to_grid_style_context = to_grid.get_style_context ();
        to_grid_style_context.add_class (Gtk.STYLE_CLASS_ENTRY);

        var cc_label = new Gtk.Label (_("Cc:"));
        cc_label.xalign = 1;
        cc_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var cc_val = new Gtk.Entry ();
        cc_val.hexpand = true;

        var cc_grid = new Gtk.Grid ();
        cc_grid.column_spacing = 6;
        cc_grid.margin_top = 6;
        cc_grid.add (cc_label);
        cc_grid.add (cc_val);

        var cc_revealer = new Gtk.Revealer ();
        cc_revealer.add (cc_grid);

        var bcc_label = new Gtk.Label (_("Bcc:"));
        bcc_label.xalign = 1;
        bcc_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var bcc_val = new Gtk.Entry ();
        bcc_val.hexpand = true;

        var bcc_grid = new Gtk.Grid ();
        bcc_grid.column_spacing = 6;
        bcc_grid.margin_top = 6;
        bcc_grid.add (bcc_label);
        bcc_grid.add (bcc_val);

        var bcc_revealer = new Gtk.Revealer ();
        bcc_revealer.add (bcc_grid);

        var subject_val = new Gtk.Entry ();
        subject_val.margin_top = 6;

        var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
        size_group.add_widget (to_label);
        size_group.add_widget (cc_label);
        size_group.add_widget (bcc_label);
        size_group.add_widget (subject_label);

        var recipient_grid = new Gtk.Grid ();
        recipient_grid.margin = 6;
        recipient_grid.margin_top = 12;
        recipient_grid.column_spacing = 6;
        recipient_grid.attach (to_label, 0, 0, 1, 1);
        recipient_grid.attach (to_grid, 1, 0, 1, 1);
        recipient_grid.attach (cc_revealer, 0, 1, 2, 1);
        recipient_grid.attach (bcc_revealer, 0, 2, 2, 1);
        recipient_grid.attach (subject_label, 0, 3, 1, 1);
        recipient_grid.attach (subject_val, 1, 3, 1, 1);

        var composer_widget = new ComposerWidget ();
        composer_widget.discarded.connect (() => {
            close ();
        });

        var content_grid = new Gtk.Grid ();
        content_grid.orientation = Gtk.Orientation.VERTICAL;
        content_grid.add (recipient_grid);
        content_grid.add (composer_widget);

        get_style_context ().add_class ("rounded");
        add (content_grid);

        var contact_manager = ContactManager.get_default ();
        contact_manager.setup_entry (to_val);
        contact_manager.setup_entry (cc_val);
        contact_manager.setup_entry (bcc_val);

        cc_button.clicked.connect (() => {
            cc_revealer.reveal_child = cc_button.active;
        });

        cc_val.changed.connect (() => {
            if (cc_val.text == "") {
                cc_button.sensitive = true;
            } else {
                cc_button.sensitive = false;
            }
        });

        bcc_button.clicked.connect (() => {
            bcc_revealer.reveal_child = bcc_button.active;
        });

        bcc_val.changed.connect (() => {
            if (bcc_val.text == "") {
                bcc_button.sensitive = true;
            } else {
                bcc_button.sensitive = false;
            }
        });

        to_val.changed.connect (() => {
            composer_widget.has_recipients = to_val.text != "";
        });

        to_val.get_style_context ().changed.connect (() => {
            var state = to_grid_style_context.get_state ();
            if (to_val.has_focus) {
                state |= Gtk.StateFlags.FOCUSED;
            } else {
                state ^= Gtk.StateFlags.FOCUSED;
            }

            to_grid_style_context.set_state (state);
        });
    }
}
