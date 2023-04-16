/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.ConversationListItem : Gtk.Box {
    private Gtk.Image status_icon;
    private Gtk.Label date;
    private Gtk.Label messages;
    private Gtk.Label source;
    private Gtk.Label topic;
    private Gtk.Revealer flagged_icon_revealer;
    private Gtk.Revealer status_revealer;

    construct {
        status_icon = new Gtk.Image.from_icon_name ("mail-unread-symbolic");

        status_revealer = new Gtk.Revealer () {
            child = status_icon
        };

        var flagged_icon = new Gtk.Image.from_icon_name ("starred-symbolic");
        flagged_icon_revealer = new Gtk.Revealer () {
            child = flagged_icon
        };

        source = new Gtk.Label (null) {
            hexpand = true,
            ellipsize = Pango.EllipsizeMode.END,
            use_markup = true,
            xalign = 0
        };
        source.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        messages = new Gtk.Label (null) {
            halign = Gtk.Align.END
        };
        messages.add_css_class (Granite.STYLE_CLASS_BADGE);
        messages.add_css_class (Granite.STYLE_CLASS_FLAT);

        topic = new Gtk.Label (null) {
            hexpand = true,
            ellipsize = Pango.EllipsizeMode.END,
            xalign = 0
        };

        date = new Gtk.Label (null) {
            halign = Gtk.Align.END
        };
        date.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        var grid = new Gtk.Grid () {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12,
            column_spacing = 12,
            row_spacing = 6
        };

        grid.attach (status_revealer, 0, 0);
        grid.attach (flagged_icon_revealer, 0, 1, 1, 1);
        grid.attach (source, 1, 0, 1, 1);
        grid.attach (date, 2, 0, 2, 1);
        grid.attach (topic, 1, 1, 2, 1);
        grid.attach (messages, 3, 1, 1, 1);

        add_css_class ("conversation-list-item");
        append (grid);
    }

    public void assign (ConversationItemModel data) {
        date.label = data.formatted_date;
        topic.label = data.subject;

        var source_label_text = "";
        if (Camel.FolderInfoFlags.TYPE_SENT == (data.folder_info_flags & Camel.FOLDER_TYPE_MASK)) {
            source_label_text = data.to;
        } else {
            source_label_text = data.from;
        }
        source.label = GLib.Markup.escape_text (source_label_text);
        tooltip_markup = GLib.Markup.printf_escaped ("<b>%s</b>\n%s", source_label_text, data.subject);

        uint num_messages = data.num_messages;
        messages.label = num_messages > 1 ? "%u".printf (num_messages) : null;
        messages.visible = num_messages > 1;
        // messages.no_show_all = num_messages <= 1;

        if (data.unread) {
            add_css_class ("unread-message");

            status_icon.icon_name = "mail-unread-symbolic";
            status_icon.tooltip_text = _("Unread");
            status_icon.add_css_class (Granite.STYLE_CLASS_ACCENT);

            status_revealer.reveal_child = true;

            source.add_css_class (Granite.STYLE_CLASS_ACCENT);
        } else {
            remove_css_class ("unread-message");
            status_icon.remove_css_class (Granite.STYLE_CLASS_ACCENT);
            source.remove_css_class (Granite.STYLE_CLASS_ACCENT);

            if (data.replied_all || data.replied) {
                status_icon.icon_name = "mail-replied-symbolic";
                status_icon.tooltip_text = _("Replied");
                status_revealer.reveal_child = true;
            } else if (data.forwarded) {
                status_icon.icon_name = "mail-forwarded-symbolic";
                status_icon.tooltip_text = _("Forwarded");
                status_revealer.reveal_child = true;
            } else {
                status_revealer.reveal_child = false;
            }
        }

        flagged_icon_revealer.reveal_child = data.flagged;
    }
}
