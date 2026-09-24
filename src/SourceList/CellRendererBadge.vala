/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 * Copyright 2012–2013 Victor Eduardo <victoreduardm@gmail.com>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

/**
 * A badge renderer.
 *
 * Informs the user quickly on the content of the corresponding view. For example
 * it might be used to show how much songs are in a playlist or how much updates
 * are available.
 *
 * @since 0.2
 */
public class Mail.CellRendererBadge : Gtk.CellRenderer {
    public string text { get; set; default = ""; }

    private Pango.Rectangle text_logical_rect;
    private Pango.Layout text_layout;
    private Gtk.Border margin;
    private Gtk.Border padding;
    private Gtk.Border border;

    public override Gtk.SizeRequestMode get_request_mode () {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    public override void get_preferred_width (
        Gtk.Widget widget,
        out int minimum_size,
        out int natural_size
    ) {
        update_layout_properties (widget);

        int width = text_logical_rect.width;
        width += margin.left + margin.right;
        width += padding.left + padding.right;
        width += border.left + border.right;

        minimum_size = natural_size = width + 2 * (int) xpad;
    }

    public override void get_preferred_height_for_width (
        Gtk.Widget widget, int width,
        out int minimum_height,
        out int natural_height
    ) {
        update_layout_properties (widget);

        int height = text_logical_rect.height;
        height += margin.top + margin.bottom;
        height += padding.top + padding.bottom;
        height += border.top + border.bottom;

        minimum_height = natural_height = height + 2 * (int) ypad;
    }

    private void update_layout_properties (Gtk.Widget widget) {
        var ctx = widget.get_style_context ();
        ctx.save ();

        // Add class before creating the pango layout and fetching paddings.
        // This is needed in order to fetch the proper style information.
        ctx.add_class (Granite.STYLE_CLASS_BADGE);

        margin = ctx.get_margin ();
        padding = ctx.get_padding ();
        border = ctx.get_border ();

        text_layout = widget.create_pango_layout (text);

        ctx.restore ();

        Pango.Rectangle ink_rect;
        text_layout.get_pixel_extents (out ink_rect, out text_logical_rect);
    }

    public override void snapshot (Gtk.Snapshot snapshot, Gtk.Widget widget, Gdk.Rectangle bg_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {
        update_layout_properties (widget);

        Gdk.Rectangle aligned_area = get_aligned_area (widget, flags, cell_area);

        int x = aligned_area.x;
        int y = aligned_area.y;
        int width = aligned_area.width;
        int height = aligned_area.height;

        // Apply margin
        x += margin.right;
        y += margin.top;
        width -= margin.left + margin.right;
        height -= margin.top + margin.bottom;

        var ctx = widget.get_style_context ();
        ctx.add_class (Granite.STYLE_CLASS_BADGE);

        snapshot.render_background (ctx, x, y, width, height);
        snapshot.render_frame (ctx, x, y, width, height);

        // Apply border width and padding offsets
        x += border.right + padding.right;
        y += border.top + padding.top;
        width -= border.left + border.right + padding.left + padding.right;
        height -= border.top + border.bottom + padding.top + padding.bottom;

        // Center text
        x += text_logical_rect.x + (width - text_logical_rect.width) / 2;
        y += text_logical_rect.y + (height - text_logical_rect.height) / 2;

        snapshot.render_layout (ctx, x, y, text_layout);
    }
}
