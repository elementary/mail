// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016 elementary LLC.
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class AttachmentWidget : Gtk.FlowBoxChild {
    public signal void save_as ();
    private Gtk.Image preview_image;
    private Gtk.Label name_label;
    private Gtk.Label size_label;

    private unowned Geary.Attachment attachment;
    public AttachmentWidget (Geary.Attachment attachment) {
        this.attachment = attachment;
        name_label.label = !attachment.has_supplied_filename ? _("none") : attachment.file.get_basename ();
        size_label.label = GLib.format_size (attachment.filesize);
        update_image ();
        
    }

    construct {
        var event_box = new Gtk.EventBox ();
        event_box.events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        event_box.button_press_event.connect ((event) => {
            if (event.button == Gdk.BUTTON_SECONDARY) {
                var item_open = new Gtk.MenuItem.with_label (_("Open"));
                item_open.activate.connect (() => activate ());
                var item_save = new Gtk.MenuItem.with_label (_("Save As…"));
                item_save.activate.connect (() => save_as ());
                var menu = new Gtk.Menu ();
                menu.add (item_open);
                menu.add (item_save);
                menu.attach_widget = this;
                menu.show_all ();
                menu.popup (null, null, null, event.button, event.time);
            } else {
                activate ();
            }

            return true;
        });

        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.column_spacing = 6;
        grid.row_spacing = 6;

        preview_image = new Gtk.Image ();
        preview_image.pixel_size = 32;
        preview_image.valign = Gtk.Align.CENTER;

        name_label = new Gtk.Label (null);
        ((Gtk.Misc) name_label).xalign = 0;
        name_label.valign = Gtk.Align.BASELINE;

        size_label = new Gtk.Label (null);
        ((Gtk.Misc) size_label).xalign = 0;
        size_label.valign = Gtk.Align.BASELINE;
        size_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        grid.attach (preview_image, 0, 0, 1, 2);
        grid.attach (name_label, 1, 0, 1, 1);
        grid.attach (size_label, 1, 1, 1, 1);
        event_box.add (grid);
        add (event_box);
    }

    private void update_image () {
        if (attachment.content_type.has_media_type ("image")) {
            preview_image.gicon = new FileIcon (attachment.file);
        } else {
            string gio_content_type = ContentType.from_mime_type (attachment.content_type.get_mime_type ());
            preview_image.gicon = ContentType.get_icon (gio_content_type);
        }

        if (preview_image.gicon == null) {
            preview_image.gicon = new ThemedIcon ("unknown");
        }
    }
}
