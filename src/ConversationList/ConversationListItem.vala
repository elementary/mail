/*-
 * Copyright (c) 2017-2026 elementary, Inc. (https://elementary.io)
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
            ellipsize = END,
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
            ellipsize = END,
            xalign = 0
        };

        date = new Gtk.Label (null) {
            halign = Gtk.Align.END
        };
        date.add_css_class (Granite.CssClass.DIM);

        grid = new Gtk.Grid () {
            margin_top = 12,
            margin_end = 12,
            margin_bottom = 12,
            margin_start = 12,
            column_spacing = 12,
            row_spacing = 6,
            hexpand = true
        };

        grid.attach (status_revealer, 0, 0);
        grid.attach (flagged_icon_revealer, 0, 1);
        grid.attach (source, 1, 0);
        grid.attach (date, 2, 0, 2);
        grid.attach (topic, 1, 1, 2);
        grid.attach (messages, 3, 1);

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
        carousel.append (grid);
        carousel.prepend (archive_affordance);
        carousel.append (trash_affordance);

        add_css_class ("conversation-list-item");
        child = carousel;

        var click_controller = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY,
            propagation_phase = BUBBLE
        };

        click_controller.released.connect ((n_press, x, y) => {
            var menu = create_context_menu ();
            menu_popup_at_pointer (menu, x, y);
        });

        var key_controller = new Gtk.EventControllerKey ();

        key_controller.key_released.connect ((keyval) => {
            if (keyval != Gdk.Key.Menu) {
                return;
            }

            var menu = create_context_menu ();
            menu_popup_on_keypress (menu);
        });

        add_controller (click_controller);
        add_controller (key_controller);

        carousel.page_changed.connect ((index) => {
            if (index == 1) {
                return;
            }

            if (index == 2) {
                activate_action (MainWindow.ACTION_PREFIX + MainWindow.ACTION_MOVE_TO_TRASH, null);
            } else if (index == 0) {
                activate_action (MainWindow.ACTION_PREFIX + MainWindow.ACTION_ARCHIVE, null);
            }
        });
    }

    public void assign (ConversationItemModel data) {
        carousel.scroll_to (grid, false);

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

        if (data.unread) {
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

    private Gtk.PopoverMenu create_context_menu () {
        var menu_model = new Menu ();
        menu_model.append (_("Move To Trash"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MOVE_TO_TRASH);

        // var item = (ConversationItemModel) model_item;
        // if (!item.unread) {
        //     menu_model.append (_("Mark As Unread"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNREAD);
        // } else {
        //     menu_model.append (_("Mark as Read"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_READ);
        // }

        // if (!item.flagged) {
        //     menu_model.append (_("Star"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_STAR);
        // } else {
        //     menu_model.append (_("Unstar"), MainWindow.ACTION_PREFIX + MainWindow.ACTION_MARK_UNSTAR);
        // }

        var menu = new Gtk.PopoverMenu.from_model (menu_model) {
            has_arrow = false,
            position = BOTTOM
        };
        menu.set_parent (this);

        return menu;
    }

    private void menu_popup_at_pointer (Gtk.PopoverMenu popover, double x, double y) {
        var rect = Gdk.Rectangle () {
            x = (int) x,
            y = (int) y
        };
        popover.pointing_to = rect;
        popover.popup ();
    }

    private void menu_popup_on_keypress (Gtk.PopoverMenu popover) {
        popover.halign = END;
        popover.set_pointing_to (Gdk.Rectangle () {
            x = (int) get_width (),
            y = (int) get_height () / 2
        });
        popover.popup ();
    }

    private class SwipeAffordance : Granite.Bin {
        public Gtk.Align alignment { get; construct; }
        public string icon_name { get; construct; }
        public string label { get; construct; }

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

            var box = new Gtk.Box (VERTICAL, 3) {
                halign = alignment,
                hexpand = true,
                valign = CENTER,
                vexpand = false
            };
            box.append (image);
            box.append (label);

            child = box;

            if (alignment == Gtk.Align.START) {
                add_css_class ("start");
            } else if (alignment == Gtk.Align.END) {
                add_css_class ("end");
            }
        }
    }
}
