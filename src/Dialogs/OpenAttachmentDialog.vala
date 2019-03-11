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

public class Mail.OpenAttachmentDialog : Granite.MessageDialog {
    public Camel.MimePart mime_part { get; construct; }

    public OpenAttachmentDialog (Gtk.Window parent, Camel.MimePart mime_part) {
        Object (
            image_icon: new ThemedIcon ("dialog-warning"),
            mime_part: mime_part,
            primary_text: _("Are you sure you want to open %s?").printf (mime_part.get_filename ()),
            secondary_text: _("Attachments may cause damage to your system if opened. Only open files from trusted sources."),
            transient_for: parent,
            buttons: Gtk.ButtonsType.CANCEL
        );
    }

    construct {
        var open_button = new Gtk.Button.with_label (_("Open Anyway"));
        open_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        add_action_widget (open_button, Gtk.ResponseType.OK);

        response.connect ((response_id) => {
            if (response_id == Gtk.ResponseType.OK) {
                show_file_anyway.begin ();
            }
        });
    }

    private async void show_file_anyway () {
        try {
            GLib.FileIOStream iostream;
            var file = File.new_tmp ("XXXXXX-%s".printf (mime_part.get_filename ()), out iostream);
            yield mime_part.content.decode_to_output_stream (iostream.output_stream, GLib.Priority.DEFAULT, null);
            yield GLib.AppInfo.launch_default_for_uri_async (file.get_uri (), (AppLaunchContext) null, null);
        } catch (Error e) {
            critical (e.message);
        }
    }
}
