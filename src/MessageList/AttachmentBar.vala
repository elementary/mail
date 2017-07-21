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

public class Mail.AttachmentBar : Gtk.FlowBox {
    public Camel.MessageInfo message_info { get; construct; }
    public unowned GLib.Cancellable loading_cancellable { get; construct; }

    public AttachmentBar (Camel.MessageInfo message_info, GLib.Cancellable loading_cancellable) {
        Object (message_info: message_info,
            loading_cancellable: loading_cancellable
        );

        open_message.begin ();
    }

    construct {
        hexpand = true;
        activate_on_single_click = true;
        var style_context = get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_TOOLBAR);
        style_context.add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
    }

    private async void open_message () {
        Camel.MimeMessage message;
        var folder = message_info.summary.folder;
        try {
            message = yield folder.get_message (message_info.uid, GLib.Priority.DEFAULT, loading_cancellable);
            yield parse_mime_content (message.content);
        } catch (Error e) {
            debug("Could not get message. %s", e.message);
        }

        show_all ();
    }

    private async void parse_mime_content (Camel.DataWrapper message_content) {
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
    }

    private void show_attachment (Camel.MimePart attachment_part) {
        var dialog = new Mail.OpenAttachmentDialog (get_toplevel () as Gtk.Window, attachment_part);
        dialog.show_all ();
        dialog.run ();
        dialog.destroy ();
    }
}
