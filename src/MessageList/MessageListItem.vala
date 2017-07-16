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

    public MessageListItem (Camel.MessageInfo message_info) {
        Object (
            margin: 12,
            message_info: message_info
        );
        open_message.begin ();
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

        if (Camel.MessageFlags.FLAGGED in (int)message_info.flags) {
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
        header.attach (starred_icon, 4, 0, 1, 1);

        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        separator.hexpand = true;

        web_view = new Mail.WebView ();
        web_view.margin = 6;

        var base_grid = new Gtk.Grid ();
        base_grid.expand = true;
        base_grid.orientation = Gtk.Orientation.VERTICAL;
        base_grid.add (header);
        base_grid.add (separator);
        base_grid.add (web_view);
        add (base_grid);
        show_all ();

        destroy.connect (() => {
            loading_cancellable.cancel ();
        });
    }

    private async void open_message () {
        Camel.MimeMessage message;
        var folder = message_info.summary.folder;
        try {
            message = yield folder.get_message (message_info.uid, GLib.Priority.DEFAULT, loading_cancellable);
            bool is_html;
            var content = yield get_mime_content (message.content, out is_html);
            if (is_html) {
                web_view.load_html (content, null);
            } else {
                web_view.load_plain_text (content);
            }
        } catch (Error e) {
            debug("Could not get message. %s", e.message);
        }
    }

    private async string get_mime_content (Camel.DataWrapper message_content, out bool is_html) {
        Camel.DataWrapper data_container = message_content;
        if (data_container is Camel.Multipart) {
            var content = data_container as Camel.Multipart;
            int content_priority = 0;
            for (uint i = 0; i < content.get_number (); i++) {
                var part = content.get_part (i);
                if (part.get_mime_type_field ().type == "multipart") {
                    return yield get_mime_content (part.content, out is_html);
                }
                int current_content_priority = get_content_type_priority (part.get_mime_type ());
                if (current_content_priority > content_priority) {
                    data_container = part.content;
                }
            }
        }

        string current_content;
        try {
            var field = data_container.get_mime_type_field ();
            debug ("%s", field.simple ());

            var os = new GLib.MemoryOutputStream.resizable ();
            yield data_container.decode_to_output_stream (os, GLib.Priority.DEFAULT, loading_cancellable);
            os.close ();
            current_content = (string) os.steal_data ();
            
            is_html = field.subtype == "html";
        } catch (Error e) {
            current_content = "Error loading the message: %s".printf (e.message);
            is_html = false;
        }

        return current_content;
    }

    public static int get_content_type_priority (string mime_type) {
        switch (mime_type) {
            case "text/plain":
                return 1;
            case "text/html":
                return 2;
            default:
                return 0;
        }
    }
}
