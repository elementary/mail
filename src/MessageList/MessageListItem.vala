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
    public Camel.Folder? folder { get; construct; }

    public MessageListItem (Camel.MessageInfo message_info, Camel.Folder? folder) {
        Object (message_info: message_info, folder: folder);
    }

    construct {
        get_style_context ().add_class ("card");
        margin = 12;

        var from_label = new Gtk.Label (_("From:"));
        from_label.halign = Gtk.Align.END;
        from_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var to_label = new Gtk.Label (_("To:"));
        to_label.halign = Gtk.Align.END;
        to_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var subject_label = new Gtk.Label (_("Subject:"));
        subject_label.halign = Gtk.Align.END;
        subject_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var from_val_label = new Gtk.Label (message_info.from);
        from_val_label.halign = Gtk.Align.START;

        var to_val_label = new Gtk.Label (message_info.to);
        to_val_label.halign = Gtk.Align.START;
        to_val_label.ellipsize = Pango.EllipsizeMode.END;

        var subject_val_label = new Gtk.Label (message_info.subject);
        subject_val_label.halign = Gtk.Align.START;

        var avatar = new Granite.Widgets.Avatar.with_default_icon (64);

        var header = new Gtk.Grid ();
        header.margin = 6;
        header.column_spacing = 12;
        header.row_spacing = 6;
        header.attach (avatar, 0, 0, 1, 3);
        header.attach (from_label, 1, 0, 1, 1);
        header.attach (to_label, 1, 1, 1, 1);
        header.attach (subject_label, 1, 2, 1, 1);
        header.attach (from_val_label, 2, 0, 1, 1);
        header.attach (to_val_label, 2, 1, 1, 1);
        header.attach (subject_val_label, 2, 2, 1, 1);

        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        separator.hexpand = true;

        var web_view = new Mail.WebView ();
        web_view.margin = 6;

        if (folder != null) {
            var message = folder.get_message_sync (message_info.uid);
            // We can now get mime parts of the message
            // TODO: Parse message and display in webview
        }

        var base_grid = new Gtk.Grid ();
        base_grid.expand = true;
        base_grid.orientation = Gtk.Orientation.VERTICAL;
        base_grid.add (header);
        base_grid.add (separator);
        base_grid.add (web_view);
        add (base_grid);
        show_all ();
    }
}
