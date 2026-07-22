/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 * Copyright 2012-2014 Victor Martinez <victoreduardm@gmail.com>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

/**
 * An interface for receiving data from other widgets via drag-and-drop.
 *
 * @since 0.3
 */
public interface Mail.SourceListDragDest : Mail.SourceList.Item {
    /**
     * Determines whether //data// can be dropped into this item.
     *
     * @param context The drag context.
     * @param data {@link Gtk.SelectionData} containing source data.
     * @return //true// if the drop is possible; //false// otherwise.
     * @since 0.3
     */
    public abstract bool data_drop_possible (Gdk.DragContext context, Gtk.SelectionData data);

    /**
     * If a data drop is deemed possible, then this method is called
     * when the data is actually dropped into this item. Any actions
     * consequence of the data received should be handled here.
     *
     * @param context The drag context.
     * @param data {@link Gtk.SelectionData} containing source data.
     * @return The action taken, or //0// to indicate that the dropped data was not accepted.
     * @since 0.3
     */
    public abstract Gdk.DragAction data_received (Gdk.DragContext context, Gtk.SelectionData data);
}
