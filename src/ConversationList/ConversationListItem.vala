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

public class Mail.ConversationListItem : VirtualizingListBoxRow {
    public signal void select ();

    private Gtk.Image status_icon;
    private Gtk.Label date;
    private Gtk.Label messages;
    private Gtk.Label source;
    private Gtk.Label topic;
    private Gtk.Revealer flagged_icon_revealer;
    private Gtk.Revealer status_revealer;
    private Gtk.Grid grid;
    private Hdy.Carousel carousel;
    private Gtk.GestureMultiPress gesture_controller;
    private Gtk.EventControllerKey key_controller;

    construct {
        status_icon = new Gtk.Image.from_icon_name ("mail-unread-symbolic", Gtk.IconSize.MENU);

        status_revealer = new Gtk.Revealer () {
            child = status_icon
        };

        var flagged_icon = new Gtk.Image.from_icon_name ("starred-symbolic", Gtk.IconSize.MENU);
        flagged_icon_revealer = new Gtk.Revealer () {
            child = flagged_icon
        };

        source = new Gtk.Label (null) {
            hexpand = true,
            ellipsize = Pango.EllipsizeMode.END,
            use_markup = true,
            xalign = 0
        };
        source.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

        messages = new Gtk.Label (null) {
            halign = Gtk.Align.END
        };

        weak Gtk.StyleContext messages_style = messages.get_style_context ();
        messages_style.add_class (Granite.STYLE_CLASS_BADGE);
        messages_style.add_class (Gtk.STYLE_CLASS_FLAT);

        topic = new Gtk.Label (null) {
            hexpand = true,
            ellipsize = Pango.EllipsizeMode.END,
            xalign = 0
        };

        date = new Gtk.Label (null) {
            halign = Gtk.Align.END
        };
        date.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

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
        archive_affordance.get_style_context ().add_class ("archive");

        var trash_affordance = new SwipeAffordance (
            _("Trash"), "edit-delete-symbolic", START
        );
        trash_affordance.get_style_context ().add_class ("trash");

        carousel = new Hdy.Carousel () {
            allow_scroll_wheel = false
        };
        carousel.add (archive_affordance);
        carousel.add (grid);
        carousel.add (trash_affordance);
        carousel.scroll_to (grid);

        get_style_context ().add_class ("conversation-list-item");
        child = carousel;

        show_all ();

        gesture_controller = new Gtk.GestureMultiPress (this) {
            button = Gdk.BUTTON_SECONDARY,
            propagation_phase = BUBBLE
        };

        gesture_controller.released.connect ((n_press, x, y) => {
            select ();
            create_context_menu (x, y);
        });

        key_controller = new Gtk.EventControllerKey (this);

        key_controller.key_released.connect ((keyval) => {
            if (keyval != Gdk.Key.Menu) {
                return;
            }

            create_context_menu ();
        });

        carousel.page_changed.connect ((index) => {
            if (index == 1) {
                return;
            }

            select ();

            var main_window = (MainWindow)get_toplevel ();
            if (index == 2) {
                main_window.activate_action (MainWindow.ACTION_MOVE_TO_TRASH, null);
            } else if (index == 0) {
                main_window.activate_action (MainWindow.ACTION_ARCHIVE, null);
            }

            Idle.add (() => {
                carousel.scroll_to_full (grid, 0);
                return Source.REMOVE;
            });
        });
    }

    public void assign (ConversationItemModel data) {
        carousel.scroll_to_full (grid, 0);

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
        messages.no_show_all = num_messages <= 1;

        if (data.unread) {
            grid.get_style_context ().add_class ("unread-message");

            status_icon.icon_name = "mail-unread-symbolic";
            status_icon.tooltip_text = _("Unread");
            status_icon.get_style_context ().add_class (Granite.STYLE_CLASS_ACCENT);

            status_revealer.reveal_child = true;

            source.get_style_context ().add_class (Granite.STYLE_CLASS_ACCENT);
        } else {
            grid.get_style_context ().remove_class ("unread-message");
            status_icon.get_style_context ().remove_class (Granite.STYLE_CLASS_ACCENT);
            source.get_style_context ().remove_class (Granite.STYLE_CLASS_ACCENT);

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

    private void create_context_menu (double? x = null, double? y = null) {
        var item = (ConversationItemModel)model_item;

        var menu = new Gtk.Menu () {
            attach_widget = this
        };

        var trash_menu_item = new Gtk.MenuItem () {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MOVE_TO_TRASH,
            child = new Granite.AccelLabel.from_action_name (
                _("Move To Trash"),
                MainWindow.ACTION_PREFIX + MainWindow.ACTION_MOVE_TO_TRASH
            )
        };

        menu.add (trash_menu_item);

        if (!item.unread) {
            var mark_unread_menu_item = new Gtk.MenuItem () {
                action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNREAD,
                child = new Granite.AccelLabel.from_action_name (
                    _("Mark As Unread"),
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNREAD
                )
            };
            menu.add (mark_unread_menu_item);
        } else {
            var mark_read_menu_item = new Gtk.MenuItem () {
                action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_READ,
                child = new Granite.AccelLabel.from_action_name (
                    _("Mark as Read"),
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_READ
                )
            };
            menu.add (mark_read_menu_item);
        }

        if (!item.flagged) {
            var mark_starred_menu_item = new Gtk.MenuItem () {
                action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_STAR,
                child = new Granite.AccelLabel.from_action_name (
                    _("Star"),
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_STAR
                )
            };
            menu.add (mark_starred_menu_item);
        } else {
            var mark_unstarred_menu_item = new Gtk.MenuItem () {
                action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNSTAR,
                child = new Granite.AccelLabel.from_action_name (
                    _("Unstar"),
                    MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNSTAR
                )
            };
            menu.add (mark_unstarred_menu_item);
        }

        menu.show_all ();
        menu.popup_at_pointer (null);

        if (x == null || y == null) {
            menu.popup_at_widget (this, Gdk.Gravity.EAST, Gdk.Gravity.CENTER, null);
        } else {
            menu.popup_at_pointer (null);
        }
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
            var image = new Gtk.Image.from_icon_name (icon_name, MENU);

            var label = new Gtk.Label (label);
            label.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);
            label.get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var box = new Gtk.Box (VERTICAL, 3) {
                halign = alignment,
                hexpand = true,
                valign = CENTER,
                vexpand = false
            };
            box.add (image);
            box.add (label);

            add (box);

            get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            if (alignment == Gtk.Align.START) {
                get_style_context ().add_class ("start");
            } else if (alignment == Gtk.Align.END) {
                get_style_context ().add_class ("end");
            }
        }
    }
}
