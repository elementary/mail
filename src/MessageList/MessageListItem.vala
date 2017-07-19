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

public class Mail.MessageListItem : Gtk.ListBoxRow {
    public Camel.MessageInfo message_info { get; construct; }

    private Mail.WebView web_view;
    private GLib.Cancellable loading_cancellable;
    private string message_content;
    private bool message_is_html = false;
    private GLib.Settings settings;

    public MessageListItem (Camel.MessageInfo message_info) {
        Object (
            margin: 12,
            message_info: message_info
        );
    }

    construct {
        loading_cancellable = new GLib.Cancellable ();

        get_style_context ().add_class ("card");

        var avatar = new Granite.Widgets.Avatar.with_default_icon (48);
        avatar.valign = Gtk.Align.START;

        var from_label = new Gtk.Label (_("From:"));
        from_label.halign = Gtk.Align.END;
        from_label.valign = Gtk.Align.START;
        from_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var to_label = new Gtk.Label (_("To:"));
        to_label.halign = Gtk.Align.END;
        to_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var subject_label = new Gtk.Label (_("Subject:"));
        subject_label.halign = Gtk.Align.END;
        subject_label.valign = Gtk.Align.START;
        subject_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var from_val_label = new Gtk.Label (message_info.from);
        from_val_label.wrap = true;
        from_val_label.xalign = 0;

        var to_val_label = new Gtk.Label (message_info.to);
        to_val_label.halign = Gtk.Align.START;
        to_val_label.ellipsize = Pango.EllipsizeMode.END;

        var subject_val_label = new Gtk.Label (message_info.subject);
        subject_val_label.xalign = 0;
        subject_val_label.wrap = true;

        var datetime_label = new Gtk.Label (new DateTime.from_unix_utc (message_info.date_received).format ("%b %e, %Y"));
        datetime_label.hexpand = true;
        datetime_label.halign = Gtk.Align.END;
        datetime_label.valign = Gtk.Align.START;
        datetime_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var starred_icon = new Gtk.Image ();
        starred_icon.icon_size = Gtk.IconSize.MENU;
        starred_icon.valign = Gtk.Align.START;

        if (Camel.MessageFlags.FLAGGED in (int) message_info.flags) {
            starred_icon.icon_name = "starred-symbolic";
        } else {
            starred_icon.icon_name = "non-starred-symbolic";
        }

        var header = new Gtk.Grid ();
        header.margin = 12;
        header.column_spacing = 6;
        header.row_spacing = 6;
        header.attach (avatar, 0, 0, 1, 3);
        header.attach (from_label, 1, 0, 1, 1);
        header.attach (to_label, 1, 1, 1, 1);
        header.attach (subject_label, 1, 2, 1, 1);
        header.attach (from_val_label, 2, 0, 1, 1);
        header.attach (to_val_label, 2, 1, 1, 1);
        header.attach (subject_val_label, 2, 2, 3, 1);
        header.attach (datetime_label, 3, 0, 1, 1);
        header.attach (starred_icon, 5, 0, 1, 1);

        if (Camel.MessageFlags.ATTACHMENTS in (int) message_info.flags) {
            var attachment_icon = new Gtk.Image.from_icon_name ("mail-attachment-symbolic", Gtk.IconSize.MENU);
            attachment_icon.tooltip_text = _("This message contains one or more attachments");
            attachment_icon.valign = Gtk.Align.START;

            header.attach (attachment_icon, 4, 0, 1, 1);
        }

        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        separator.hexpand = true;

        settings = new GLib.Settings ("io.elementary.mail");

        web_view = new Mail.WebView ();
        web_view.margin = 6;
        web_view.image_load_blocked.connect (() => {
            // TODO: Show infobar
        });
        web_view.mouse_target_changed.connect (on_mouse_target_changed);

        get_message.begin ();

        var base_grid = new Gtk.Grid ();
        base_grid.expand = true;
        base_grid.orientation = Gtk.Orientation.VERTICAL;
        base_grid.add (header);
        base_grid.add (separator);
        base_grid.add (web_view);

        if (Camel.MessageFlags.ATTACHMENTS in (int)message_info.flags) {
            var attachment_bar = new AttachmentBar (message_info, loading_cancellable);
            base_grid.add (attachment_bar);
        }

        add (base_grid);
        show_all ();

        destroy.connect (() => {
            loading_cancellable.cancel ();
        });
    }

    private void on_mouse_target_changed (WebKit.WebView web_view, WebKit.HitTestResult hit_test, uint mods) {
        var list_box = this.parent as MessageListBox;
        if (hit_test.context_is_link ()) {
            list_box.hovering_over_link (hit_test.get_link_label (), hit_test.get_link_uri ());
        } else {
            list_box.hovering_over_link (null, null);
        }
    }

    private async void get_message () {
        var folder = message_info.summary.folder;
        Camel.MimeMessage? message = null;
        try {
            message = yield folder.get_message (message_info.uid, GLib.Priority.DEFAULT, loading_cancellable);
        } catch (Error e) {
            warning ("Could not get message. %s", e.message);
        }

        if (settings.get_boolean ("always-load-remote-images")) {
            web_view.load_images ();
        } else if (message != null) {
            var allowed_emails = settings.get_strv ("remote-images-whitelist");
            var whitelist = new Gee.ArrayList<string>.wrap (allowed_emails);
            string from_address;
            message.get_from ().@get (0, null, out from_address);
            if (whitelist.contains (from_address)) {
                web_view.load_images ();
            }
        }

        if (message != null) {
            yield open_message (message);
        }
    }

    private async void open_message (Camel.MimeMessage message) {
        yield parse_mime_content (message.content);
        if (message_is_html) {
            web_view.load_html (message_content, null);
        } else {
            web_view.load_plain_text (message_content);
        }
    }

    private async void parse_mime_content (Camel.DataWrapper message_content) {
        if (message_content is Camel.Multipart) {
            var content = message_content as Camel.Multipart;
            for (uint i = 0; i < content.get_number (); i++) {
                var part = content.get_part (i);
                var field = part.get_mime_type_field ();
                if (part.disposition == "inline") {
                    yield handle_inline_mime (part);
                } else if (field.type == "text") {
                    yield handle_text_mime (part.content);
                } else if (field.type == "multipart") {
                    yield parse_mime_content (part.content);
                }
            }
        } else {
            yield handle_text_mime (message_content);
        }
    }

    private async void handle_text_mime (Camel.DataWrapper part) {
        var field = part.get_mime_type_field ();
        if (message_content == null || (!message_is_html && field.subtype == "html")) {
            var os = new GLib.MemoryOutputStream.resizable ();
            try {
                yield part.decode_to_output_stream (os, GLib.Priority.DEFAULT, loading_cancellable);
                os.close ();
            } catch (Error e) {
                warning ("Possible error decoding email message: %s", e.message);
                return;
            }

            message_content = (string) os.steal_data ();
            if (field.subtype == "html") {
                message_is_html = true;
            }
        }
    }

    private async void handle_inline_mime (Camel.MimePart part) {
        var byte_array = new ByteArray ();
        var os = new Camel.StreamMem ();
        os.set_byte_array (byte_array);
        try {
            yield part.content.decode_to_stream (os, GLib.Priority.DEFAULT, loading_cancellable);
        } catch (Error e) {
            warning ("Error decoding inline attachment: %s", e.message);
            return;
        }

        Bytes bytes;
        bytes = ByteArray.free_to_bytes (byte_array);
        var inline_stream = new MemoryInputStream.from_bytes (bytes);
        web_view.add_internal_resource (part.get_content_id (), inline_stream);
    }
}
