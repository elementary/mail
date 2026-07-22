/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 * Copyright 2012-2014 Victor Martinez <victoreduardm@gmail.com>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

/**
 * An interface for dragging items out of the source list widget.
 *
 * @since 0.3
 */
public interface Mail.SourceListDragSource : Mail.SourceList.Item {
    /**
     * Determines whether this item can be dragged outside the source list widget.
     *
     * Even if this method returns //false//, the item could still be dragged around
     * within the source list if its parent allows DnD reordering. This only happens
     * when the parent implements {@link Granite.Widgets.SourceListSortable}.
     *
     * @return //true// if the item can be dragged; //false// otherwise.
     * @since 0.3
     * @see Granite.Widgets.SourceListSortable
     */
    public abstract bool draggable ();

    /**
     * This method is called when the drop site requests the data which is dragged.
     *
     * It is the responsibility of this method to fill //selection_data// with the
     * data in the format which is indicated by {@link Gtk.SelectionData.get_target}.
     *
     * @param selection_data {@link Gtk.SelectionData} containing source data.
     * @since 0.3
     * @see Gtk.SelectionData.set
     * @see Gtk.SelectionData.set_uris
     * @see Gtk.SelectionData.set_text
     */
    public abstract void prepare_selection_data (Gtk.SelectionData selection_data);
}
