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

public class Mail.CellRendererAvatar : Gtk.CellRendererPixbuf {
    public int margin = 3;

    public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {
        var style_context = widget.get_style_context ();
        style_context.save ();
        style_context.add_class ("avatar");
        int size = int.min (cell_area.width - 2 * margin, cell_area.height - 2 * margin);
        int x = cell_area.x + margin;
        int y = cell_area.y + (cell_area.height - size)/2;
        var border_radius = style_context.get_property (Gtk.STYLE_PROPERTY_BORDER_RADIUS, style_context.get_state ()).get_int ();
        var crop_radius = int.min (size / 2, border_radius * size / 100);
        var scale_factor = style_context.get_scale ();

        Gdk.Pixbuf pb = null;
        if (gicon != null && gicon is LoadableIcon) {
            style_context.render_background (cr, x, y, size, size);
            Granite.Drawing.Utilities.cairo_rounded_rectangle (cr, x, y, size, size, crop_radius);
            try {
                pb = new Gdk.Pixbuf.from_stream_at_scale (((LoadableIcon)gicon).load (size * scale_factor, null, null), size * scale_factor, size * scale_factor, true);
            } catch (Error e) {
                critical (e.message);
            }
        }

        if (pb != null) {
            cr.save ();
            cr.scale (1.0 / scale_factor, 1.0 / scale_factor);
            Gdk.cairo_set_source_pixbuf (cr, pb, x * scale_factor, y * scale_factor);
            cr.fill_preserve ();
            cr.restore ();

            style_context.render_frame (cr, x, y, size, size);
        }

        style_context.restore ();
    }

    public override void get_preferred_width_for_height (Gtk.Widget widget, int height, out int minimum_width, out int natural_width) {
        var style_context = widget.get_style_context ();
        style_context.save ();
        style_context.add_class ("avatar");
        base.get_preferred_width_for_height (widget, height, out minimum_width, out natural_width);
        minimum_width += 2 * margin;
        natural_width += 2 * margin;
        style_context.restore ();
    }


    public override void get_preferred_width (Gtk.Widget widget, out int minimum_size, out int natural_size) {
        var style_context = widget.get_style_context ();
        style_context.save ();
        style_context.add_class ("avatar");
        base.get_preferred_width (widget, out minimum_size, out natural_size);
        minimum_size += 2 * margin;
        natural_size += 2 * margin;
        style_context.restore ();
    }

    public override void get_preferred_height_for_width (Gtk.Widget widget, int width, out int minimum_height, out int natural_height) {
        var style_context = widget.get_style_context ();
        style_context.save ();
        style_context.add_class ("avatar");
        base.get_preferred_height_for_width (widget, width, out minimum_height, out natural_height);
        style_context.restore ();
    }

    public override void get_preferred_height (Gtk.Widget widget, out int minimum_size, out int natural_size) {
        var style_context = widget.get_style_context ();
        style_context.save ();
        style_context.add_class ("avatar");
        base.get_preferred_height (widget, out minimum_size, out natural_size);
        style_context.restore ();
    }
}
