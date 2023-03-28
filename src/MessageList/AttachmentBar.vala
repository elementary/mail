/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017-2023 elementary, Inc. (https://elementary.io)
 */

public class Mail.AttachmentBar : Gtk.FlowBox {
    public unowned GLib.Cancellable loading_cancellable { get; construct; }

    public AttachmentBar (GLib.Cancellable loading_cancellable) {
        Object (loading_cancellable: loading_cancellable);
    }

    construct {
        hexpand = true;
        activate_on_single_click = true;

        var style_context = get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_FLAT);
        style_context.add_class ("bottom-toolbar");
    }

    public async void parse_mime_content (Camel.DataWrapper message_content) {
        if (message_content is Camel.Multipart) {
            var content = message_content as Camel.Multipart;
            for (uint i = 0; i < content.get_number (); i++) {
                var part = content.get_part (i);
                var field = part.get_mime_type_field ();
                if (part.disposition == "attachment") {
                    var button = new AttachmentButton (part, loading_cancellable);
                    button.activate.connect (() => show_attachment (button.mime_part));
                    add (button);
                } else if (field.type == "multipart") {
                    yield parse_mime_content (part.content);
                }
            }
        }

        show_all ();
    }

    private void show_attachment (Camel.MimePart mime_part) {
        var dialog = new Granite.MessageDialog (
            _("Trust and open “%s”?").printf (mime_part.get_filename ()),
            _("Attachments may cause damage to your system if opened. Only open files from trusted sources."),
            new ThemedIcon ("dialog-warning"),
            Gtk.ButtonsType.CANCEL
        ) {
            transient_for = (Gtk.Window) get_toplevel ()
        };

        var open_button = dialog.add_button (_("Open Anyway"), Gtk.ResponseType.OK);
        open_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        dialog.present ();
        dialog.response.connect ((response_id) => {
            if (response_id == Gtk.ResponseType.OK) {
                show_file_anyway.begin (mime_part);
            }

            dialog.destroy ();
        });
    }

    private async void show_file_anyway (Camel.MimePart mime_part) {
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
