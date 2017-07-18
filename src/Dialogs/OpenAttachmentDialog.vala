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

public class Mail.OpenAttachmentDialog : Gtk.Dialog {
    public Camel.MimePart mime_part { get; construct; }

    public OpenAttachmentDialog (Camel.MimePart mime_part) {
        Object (
            deletable: false,
            mime_part: mime_part,
            resizable: false
        );
    }

    construct {
        var warning_image = new Gtk.Image.from_icon_name ("dialog-warning", Gtk.IconSize.DIALOG);
        warning_image.valign = Gtk.Align.START;

        var primary_text = _("Are you sure you want to open %s?").printf (mime_part.get_filename ());
        var primary_label = new Gtk.Label (primary_text);
        primary_label.max_width_chars = 60;
        primary_label.wrap = true;
        primary_label.xalign = 0;
        primary_label.get_style_context ().add_class ("primary");

        var secondary_label = new Gtk.Label (_("Attachments may cause damage to your system if opened. Only open files from trusted sources."));
        secondary_label.max_width_chars = 60;
        secondary_label.wrap = true;
        secondary_label.xalign = 0;

        var open_button = new Gtk.Button.with_label (_("Open Anyway"));
        open_button.get_style_context ().add_class ("destructive-action");

        var layout = new Gtk.Grid ();
        layout.margin = 12;
        layout.margin_top = 0;
        layout.column_spacing = 12;
        layout.row_spacing = 6;
        layout.attach (warning_image, 0, 0, 1, 2);
        layout.attach (primary_label, 1, 0, 1, 1);
        layout.attach (secondary_label, 1, 1, 1, 1);

        ((Gtk.Box) get_content_area ()).add (layout);

        ((Gtk.Box) get_action_area ()).margin = 5;

        add_button (_("Cancel"), Gtk.ResponseType.CLOSE);
        add_action_widget (open_button, Gtk.ResponseType.OK);
        response.connect ((response_id) => {
            if (response_id == Gtk.ResponseType.OK) {
                show_file_anyway.begin ();
            }
        });

        show_all ();
    }

    private async void show_file_anyway () {
        try {
            GLib.FileIOStream iostream;
            var file = File.new_tmp ("XXXXXX-%s".printf (mime_part.get_filename ()), out iostream);
            yield mime_part.content.decode_to_output_stream (iostream.output_stream, GLib.Priority.DEFAULT, null);
            yield GLib.AppInfo.launch_default_for_uri_async (file.get_uri (), null, null);
        } catch (Error e) {
            critical (e.message);
        }
    }
}
