// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2018 elementary LLC. (https://elementary.io)
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
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public class Mail.ConversationItemRenderer : Gtk.CellRenderer {
    public ConversationItemModel conversation { get; set; }

    public const int LINE_SPACING = 10;

    private const string STYLE_EXAMPLE = "Gg";
    private const int LEFT_ICON_SIZE = 16;
    private const int TEXT_LEFT = LINE_SPACING * 2 + LEFT_ICON_SIZE;

    private const int FONT_SIZE_DATE = 9;
    private const int FONT_SIZE_SUBJECT = 9;
    private const int FONT_SIZE_FROM = 11;

    private static int cell_height = -1;

    private static int current_scale_factor = 1;
    private bool is_dummy { get; private set; }

    private string subject {
        get {
            return conversation.topic;
        }
    }

    private string from {
        get {
            return conversation.from;
        }
    }

    private string date {
        get {
            return conversation.formatted_date;
        }
    }

    private bool is_unread {
        get {
            return conversation.unread;
        }
    }

    public override void get_size (Gtk.Widget widget, Gdk.Rectangle? cell_area, out int x_offset,
        out int y_offset, out int width, out int height) {

        style_changed (widget);

        x_offset = 0;
        y_offset = 0;
        // set width to 1 (rather than 0) to work around certain themes that cause the
        // conversation list to be shown as "squished":
        // https://bugzilla.gnome.org/show_bug.cgi?id=713954
        width = 1;
        height = cell_height;
    }

    public override void render (Cairo.Context ctx, Gtk.Widget widget, Gdk.Rectangle background_area,
        Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {

        render_internal (widget, cell_area, ctx, flags, false, false);
    }

    public void style_changed (Gtk.Widget widget) {
        calculate_sizes (widget);
    }

    public void calculate_sizes (Gtk.Widget widget) {
        render_dummy (widget, null, null);
    }

    public void render_dummy (Gtk.Widget widget, Gdk.Rectangle? cell_area, Cairo.Context? ctx) {
        is_dummy = true;

        int y = LINE_SPACING + (cell_area != null ? cell_area.y : 0);

        var ink_rect = render_date (widget, cell_area, ctx, y);

        ink_rect = render_from (widget, cell_area, ctx, y, ink_rect);
        y += ink_rect.height + ink_rect.y + LINE_SPACING;

        render_subject (widget, cell_area, ctx, y);
        y += ink_rect.height + ink_rect.y + LINE_SPACING;

        ConversationItemRenderer.cell_height = y;

        is_dummy = false;
    }

    private void render_internal (Gtk.Widget widget, Gdk.Rectangle? cell_area, Cairo.Context? ctx,
        Gtk.CellRendererState flags, bool recalc_dims) {

        int y = LINE_SPACING + (cell_area != null ? cell_area.y : 0);

        var selected = (flags & Gtk.CellRendererState.SELECTED) != 0;
        var ink_rect = render_date (widget, cell_area, ctx, y);

        ink_rect = render_from (widget, cell_area, ctx, y, ink_rect);
        y += ink_rect.height + ink_rect.y + LINE_SPACING;

        render_subject (widget, cell_area, ctx, y);
        y += ink_rect.height + ink_rect.y + LINE_SPACING;

        if (recalc_dims) {
            ConversationItemRenderer.cell_height = y;
        }
    }

    private Pango.Rectangle render_date (Gtk.Widget widget, Gdk.Rectangle? cell_area, Cairo.Context? ctx, int y) {
        Pango.Rectangle? ink_rect;
        var layout_date = widget.create_pango_layout(null);
        var font_date = layout_date.get_context ().get_font_description ();
        font_date.set_size(FONT_SIZE_DATE * Pango.SCALE);
        if (is_unread) {
            font_date.set_weight (Pango.Weight.BOLD);
        }
        layout_date.set_font_description(font_date);
        layout_date.set_markup(is_dummy ? STYLE_EXAMPLE : date, -1);
        if (widget.get_direction() == Gtk.TextDirection.RTL) {
            layout_date.set_alignment(Pango.Alignment.LEFT);
        } else {
            layout_date.set_alignment(Pango.Alignment.RIGHT);
        }

        layout_date.get_pixel_extents(out ink_rect, null);
        if (ctx != null && cell_area != null) {
            if (widget.get_direction() == Gtk.TextDirection.RTL) {
                widget.get_style_context ().render_layout (ctx, cell_area.x + LINE_SPACING, y, layout_date);
            } else {
                widget.get_style_context ().render_layout (ctx, cell_area.width - ink_rect.width, y, layout_date);
            }
        }
        return ink_rect;
    }

    private Pango.Rectangle render_from(Gtk.Widget widget, Gdk.Rectangle? cell_area, Cairo.Context? ctx, int y, Pango.Rectangle ink_rect) {
        var font_from = new Pango.FontDescription();
        font_from.set_size(FONT_SIZE_FROM * Pango.SCALE);
        if (is_unread) {
            font_from.set_weight(Pango.Weight.BOLD);
        }
        Pango.Layout layout_from = widget.create_pango_layout(null);
        layout_from.set_font_description(font_from);
        layout_from.set_markup(is_dummy ? STYLE_EXAMPLE : from, -1);
        if (widget.get_direction() == Gtk.TextDirection.RTL) {
            layout_from.set_ellipsize(Pango.EllipsizeMode.START);
        } else {
            layout_from.set_ellipsize(Pango.EllipsizeMode.END);
        }
        if (ctx != null && cell_area != null) {
            layout_from.set_width((cell_area.width - ink_rect.width - ink_rect.x - (LINE_SPACING * 3) -
                TEXT_LEFT)
            * Pango.SCALE);
            if (widget.get_direction() == Gtk.TextDirection.RTL) {
                widget.get_style_context ().render_layout (ctx, cell_area.x + ink_rect.width + LINE_SPACING * 2 , y, layout_from);
            } else {
                widget.get_style_context ().render_layout (ctx, cell_area.x + TEXT_LEFT, y, layout_from);
            }
        }
        return ink_rect;
    }

    private void render_subject(Gtk.Widget widget, Gdk.Rectangle? cell_area, Cairo.Context? ctx, int y) {
        var font_subject = new Pango.FontDescription();
        font_subject.set_size(FONT_SIZE_SUBJECT * Pango.SCALE);
        if (is_unread) {
            font_subject.set_weight(Pango.Weight.BOLD);
        }
        var layout_subject = widget.create_pango_layout(null);
        layout_subject.set_font_description(font_subject);
        layout_subject.set_markup(is_dummy ? STYLE_EXAMPLE : subject, -1);
        if (cell_area != null)
            layout_subject.set_width((cell_area.width - TEXT_LEFT - LINE_SPACING) * Pango.SCALE);

        if (widget.get_direction() == Gtk.TextDirection.RTL) {
            layout_subject.set_ellipsize(Pango.EllipsizeMode.START);
        } else {
            layout_subject.set_ellipsize(Pango.EllipsizeMode.END);
        }

        if (ctx != null && cell_area != null) {
            if (widget.get_direction() == Gtk.TextDirection.RTL) {
                widget.get_style_context ().render_layout (ctx, cell_area.x, y, layout_subject);
            } else {
                widget.get_style_context ().render_layout (ctx, cell_area.x + TEXT_LEFT, y, layout_subject);
            }
        }
    }

}


