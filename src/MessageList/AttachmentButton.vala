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

    private const string ACTION_GROUP_PREFIX = "attachmentbutton";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    private const string ACTION_OPEN = "open";
    private const string ACTION_SAVE_AS = "save-as";

    private Gtk.Image preview_image;
    private Gtk.Label name_label;
    private Gtk.Label size_label;

    public AttachmentButton (Camel.MimePart mime_part, GLib.Cancellable loading_cancellable) {
        Object (mime_part: mime_part,
            loading_cancellable: loading_cancellable
        );
    }

    construct {
        margin_top = 6;
        margin_bottom = 6;
        margin_start = 6;
        margin_end = 6;

        var open_action = new SimpleAction (ACTION_OPEN, null);
        open_action.activate.connect (() => activate ());
        var save_as_action = new SimpleAction (ACTION_SAVE_AS, null);
        save_as_action.activate.connect (on_save_as);

        var actions = new SimpleActionGroup ();
        actions.add_action (open_action);
        actions.add_action (save_as_action);
        insert_action_group (ACTION_GROUP_PREFIX, actions);

        var context_menu_model = new Menu ();
        context_menu_model.append (_("Open"), ACTION_PREFIX + ACTION_OPEN);
        context_menu_model.append (_("Save As…"), ACTION_PREFIX + ACTION_SAVE_AS);

        var menu = new Gtk.Menu.from_model (context_menu_model);

        var grid = new Gtk.Grid () {
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 6,
            margin_end = 6,
            column_spacing = 6
        };

        var mime_type = mime_part.get_content_type ().simple ();
        var glib_type = GLib.ContentType.from_mime_type (mime_type);
        var content_icon = GLib.ContentType.get_icon (glib_type);

        preview_image = new Gtk.Image.from_gicon (content_icon, Gtk.IconSize.DND) {
            valign = Gtk.Align.CENTER
        };

        name_label = new Gtk.Label (mime_part.get_filename ()) {
            xalign = 0
        };

        size_label = new Gtk.Label (null) {
            xalign = 0
        };
        size_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

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
                    size_label.get_style_context ().add_class (Gtk.STYLE_CLASS_ERROR);
                }

                return GLib.Source.REMOVE;
            });

            return null;
        });

        grid.attach (preview_image, 0, 0, 1, 2);
        grid.attach (name_label, 1, 0, 1, 1);
        grid.attach (size_label, 1, 1, 1, 1);

        var event_box = new Gtk.EventBox () {
            child = grid
        };

        child = event_box;
        show_all ();

        var gesture_click = new Gtk.GestureMultiPress (event_box) {
            button = 0
        };

        gesture_click.released.connect ((n_press, x, y) => {
            if (gesture_click.get_current_button () == Gdk.BUTTON_SECONDARY) {
                menu.attach_widget = this;
                menu.popup_at_pointer ();
            } else {
                activate ();
            }

            gesture_click.set_state (CLAIMED);
        });
    }

    private void on_save_as () {
        Gtk.Window? parent_window = get_toplevel () as Gtk.Window;
        var chooser = new Gtk.FileChooserNative (
            null,
            parent_window,
            Gtk.FileChooserAction.SAVE,
            _("Save"),
            _("Cancel")
        );

        chooser.set_current_name (mime_part.get_filename ());
        chooser.do_overwrite_confirmation = true;

        if (chooser.run () == Gtk.ResponseType.ACCEPT) {
            write_to_file.begin (chooser.get_file ());
        }

        chooser.destroy ();
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
