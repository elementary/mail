/*
 * Copyright 2019 elementary, Inc. (https://elementary.io)
 * Copyright 2012-2014 Victor Martinez <victoreduardm@gmail.com>
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

/**
 * An interface for sorting items.
 *
 * @since 0.3
 */
public interface Mail.SourceListSortable : Mail.SourceList.ExpandableItem {
    /**
     * Emitted after a user has re-ordered an item via DnD.
     *
     * @param moved The item that was moved to a different position by the user.
     * @since 0.3
     */
    public signal void user_moved_item (SourceList.Item moved);

    /**
     * Whether this item will allow users to re-arrange its children via DnD.
     *
     * This feature can co-exist with a sort algorithm (implemented
     * by {@link Granite.Widgets.SourceListSortable.compare}), but
     * the actual order of the items in the list will always
     * honor that method. The sort function has to be compatible with
     * the kind of DnD reordering the item wants to allow, since the user can
     * only reorder those items for which //compare// returns 0.
     *
     * @return Whether the item's children can be re-arranged by users.
     * @since 0.3
     */
    public abstract bool allow_dnd_sorting ();

    /**
     * Should return a negative integer, zero, or a positive integer if ''a''
     * sorts //before// ''b'', ''a'' sorts //with// ''b'', or ''a'' sorts
     * //after// ''b'' respectively. If two items compare as equal, their
     * order in the sorted source list is undefined.
     *
     * In order to ensure that the source list behaves as expected, this
     * method must define a partial order on the source list tree; i.e. it
     * must be reflexive, antisymmetric and transitive. Not complying with
     * those requirements could make the program fall into an infinite loop
     * and freeze the user interface.
     *
     * Should return //0// to allow any pair of items to be sortable via DnD.
     *
     * @param a First item.
     * @param b Second item.
     * @return A //negative// integer if //a// sorts before //b//,
     *         //zero// if //a// equals //b//, or a //positive//
     *         integer if //a// sorts after //b//.
     * @since 0.3
     */
    public abstract int compare (SourceList.Item a, SourceList.Item b);
}
