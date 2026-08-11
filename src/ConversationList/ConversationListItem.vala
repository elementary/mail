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

public class Mail.ConversationListItem : Granite.Bin {
    public signal void secondary_click (double x, double y);

    private Gtk.Image status_icon;
    private Gtk.Label date;
    private Gtk.Label messages;
    private Gtk.Label source;
    private Gtk.Label topic;
    private Gtk.Revealer flagged_icon_revealer;
    private Gtk.Revealer status_revealer;
    private Gtk.Grid grid;
    private Adw.Carousel carousel;

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
        date.add_css_class (Granite.CssClass.DIM);

        grid = new Gtk.Grid () {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12,
            column_spacing = 12,
            row_spacing = 6,
            hexpand = true
        };

        grid.attach (status_revealer, 0, 0);
        grid.attach (flagged_icon_revealer, 0, 1, 1, 1);
        grid.attach (source, 1, 0, 1, 1);
        grid.attach (date, 2, 0, 2, 1);
        grid.attach (topic, 1, 1, 2, 1);
        grid.attach (messages, 3, 1, 1, 1);

        var archive_affordance = new SwipeAffordance (
            _("Archive"), "mail-archive-symbolic", END
        );
        archive_affordance.add_css_class ("archive");

        var trash_affordance = new SwipeAffordance (
            _("Trash"), "edit-delete-symbolic", START
        );
        trash_affordance.add_css_class ("trash");

        carousel = new Adw.Carousel () {
            allow_scroll_wheel = false
        };
        carousel.append (archive_affordance);
        carousel.append (grid);
        carousel.append (trash_affordance);
        carousel.scroll_to (grid, true);

        add_css_class ("conversation-list-item");
        child = carousel;

        var gesture_controller = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY,
            propagation_phase = BUBBLE
        };

        gesture_controller.released.connect ((n_press, x, y) => {
            secondary_click (x, y);
        });

        var key_controller = new Gtk.EventControllerKey ();

        key_controller.key_released.connect ((keyval) => {
            if (keyval != Gdk.Key.Menu) {
                return;
            }

            secondary_click (-1, -1);
        });

        add_controller (gesture_controller);
        add_controller (key_controller);

        carousel.page_changed.connect ((index) => {
            if (index == 1) {
                return;
            }

            var main_window = (MainWindow)get_root ();
            if (index == 2) {
                main_window.activate_action (MainWindow.ACTION_MOVE_TO_TRASH, null);
            } else if (index == 0) {
                main_window.activate_action (MainWindow.ACTION_ARCHIVE, null);
            }

            Idle.add (() => {
                carousel.scroll_to (grid, false);
                return Source.REMOVE;
            });
        });
    }

    public void assign (ConversationItemModel item_model) {
        carousel.scroll_to (grid, false);

        date.label = item_model.formatted_date;
        topic.label = item_model.subject;

        var source_label_text = "";
        if (Camel.FolderInfoFlags.TYPE_SENT == (item_model.folder_info_flags & Camel.FOLDER_TYPE_MASK)) {
            source_label_text = item_model.to;
        } else {
            source_label_text = item_model.from;
        }
        source.label = GLib.Markup.escape_text (source_label_text);
        tooltip_markup = GLib.Markup.printf_escaped ("<b>%s</b>\n%s", source_label_text, item_model.subject);

        uint num_messages = item_model.num_messages;
        messages.label = num_messages > 1 ? "%u".printf (num_messages) : null;
        messages.visible = num_messages > 1;

        if (item_model.unread) {
            grid.add_css_class ("unread-message");

            status_icon.icon_name = "mail-unread-symbolic";
            status_icon.tooltip_text = _("Unread");
            status_icon.add_css_class (Granite.CssClass.ACCENT);

            status_revealer.reveal_child = true;

            source.add_css_class (Granite.CssClass.ACCENT);
        } else {
            grid.remove_css_class ("unread-message");
            status_icon.remove_css_class (Granite.CssClass.ACCENT);
            source.remove_css_class (Granite.CssClass.ACCENT);

            if (item_model.replied_all || item_model.replied) {
                status_icon.icon_name = "mail-replied-symbolic";
                status_icon.tooltip_text = _("Replied");
                status_revealer.reveal_child = true;
            } else if (item_model.forwarded) {
                status_icon.icon_name = "mail-forwarded-symbolic";
                status_icon.tooltip_text = _("Forwarded");
                status_revealer.reveal_child = true;
            } else {
                status_revealer.reveal_child = false;
            }
        }

        flagged_icon_revealer.reveal_child = item_model.flagged;
    }

    private class SwipeAffordance : Gtk.Box {
        public Gtk.Align alignment { get; construct; }
        public string icon_name { get; construct; }
        public string label { get; construct; }

        private static Gtk.CssProvider provider;

        static construct {
            provider = new Gtk.CssProvider ();
            provider.load_from_resource ("io/elementary/mail/ConversationListItem.css");
        }

        class construct {
            set_css_name ("affordance");
        }

        public SwipeAffordance (string label, string icon_name, Gtk.Align alignment) {
            Object (
                alignment: alignment,
                icon_name: icon_name,
                label: label
            );
        }

        construct {
            var image = new Gtk.Image.from_icon_name (icon_name);

            var label = new Gtk.Label (label);
            label.add_css_class (Granite.CssClass.SMALL);
            label.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var box = new Gtk.Box (VERTICAL, 3) {
                halign = alignment,
                hexpand = true,
                valign = CENTER,
                vexpand = false
            };
            box.append (image);
            box.append (label);

            append (box);

            get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            if (alignment == Gtk.Align.START) {
                add_css_class ("start");
            } else if (alignment == Gtk.Align.END) {
                add_css_class ("end");
            }
        }
    }
}
