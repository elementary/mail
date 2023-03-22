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

public class AttachmentButton : Gtk.FlowBoxChild {
    public Camel.MimePart mime_part { get; construct; }
    public unowned GLib.Cancellable loading_cancellable { get; construct; }

    private Gtk.Image preview_image;
    private Gtk.Label name_label;
    private Gtk.Label size_label;

    public AttachmentButton (Camel.MimePart mime_part, GLib.Cancellable loading_cancellable) {
        Object (mime_part: mime_part,
            loading_cancellable: loading_cancellable
        );
    }

    construct {
        margin_start = 6;
        margin_end = 6;
        margin_top = 6;
        margin_bottom = 6;

        var gesture_primary_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_PRIMARY
        };

        this.add_controller (gesture_primary_click);
        gesture_primary_click.released.connect (() => activate ());

        var popover = new Gtk.Popover () {
            has_arrow = false
        };
        popover.add_css_class (Granite.STYLE_CLASS_MENU);
        popover.set_parent (this);

        var item_open = new Gtk.Button.with_label (_("Open"));
        item_open.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        item_open.clicked.connect (() => {
            activate ();
            popover.popdown ();
        });

        var item_save = new Gtk.Button.with_label (_("Save As…"));
        item_save.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        item_save.clicked.connect (() =>  {
            save_as_activated ();
            popover.popdown ();
        });

        var popover_content = new Gtk.Box (VERTICAL, 0);
        popover_content.append (item_open);
        popover_content.append (item_save);

        popover.child = popover_content;

        var gesture_secondary_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };

        this.add_controller (gesture_secondary_click);
        gesture_secondary_click.pressed.connect ((n_press, x, y) => {
                var rect = Gdk.Rectangle () {
                    x = (int) x,
                    y = (int) y
                };
                popover.pointing_to = rect;
                popover.popup ();
        });

        var grid = new Gtk.Grid ();
        grid.margin_start = 6;
        grid.margin_end = 6;
        grid.margin_top = 6;
        grid.margin_bottom = 6;
        grid.column_spacing = 6;

        var mime_type = mime_part.get_content_type ().simple ();
        var glib_type = GLib.ContentType.from_mime_type (mime_type);
        var content_icon = GLib.ContentType.get_icon (glib_type);

        preview_image = new Gtk.Image.from_gicon (content_icon);
        preview_image.valign = Gtk.Align.CENTER;

        name_label = new Gtk.Label (mime_part.get_filename ());
        name_label.xalign = 0;

        size_label = new Gtk.Label (null);
        size_label.xalign = 0;
        size_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        new Thread<void*> (null, () => {
            string? size_text = null;
            try {
                var size = mime_part.calculate_decoded_size_sync (loading_cancellable);
                size_text = GLib.format_size (size);
            } catch (Error e) {
                critical (e.message);
            }

            Idle.add (() => {
                if (size_text != null) {
                    size_label.label = size_text;
                } else {
                    size_label.label = _("Unknown");
                    size_label.add_css_class (Granite.STYLE_CLASS_ERROR);
                }

                return GLib.Source.REMOVE;
            });

            return null;
        });

        grid.attach (preview_image, 0, 0, 1, 2);
        grid.attach (name_label, 1, 0, 1, 1);
        grid.attach (size_label, 1, 1, 1, 1);
        set_child (grid);
    }

    private void save_as_activated () {
        // var parent_window = (Gtk.Window) get_root ();
        // var chooser = new Gtk.FileDialog () {
        //     accept_label = _("Save"),
        //     initial_name = mime_part.get_filename ()
        // };

        // chooser.save.begin (parent_window, loading_cancellable, (obj, res) => {
        //     try {
        //         var file = chooser.save.end ();
        //         yield write_to_file (file);
        //     } catch (Error e) {
        //         critical ("Failed to save the file: %s", e.message);
        //     }
        // });
    }

    private async void write_to_file (GLib.File file) {
        try {
            var iostream = yield file.create_readwrite_async (GLib.FileCreateFlags.REPLACE_DESTINATION, GLib.Priority.DEFAULT, null);
            yield mime_part.content.decode_to_output_stream (iostream.output_stream, GLib.Priority.DEFAULT, null);
        } catch (Error e) {
            critical (e.message);
        }
    }
}
