// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
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

public class Mail.ConversationListStore : ListModel, Object {
    public delegate bool RowVisibilityFunc (GLib.Object row);

    private Gee.HashSet<weak GLib.Object> selected_rows = new Gee.HashSet<weak GLib.Object> ();
    private GLib.Sequence<ConversationItemModel> data = new GLib.Sequence<ConversationItemModel> ();
    private uint last_position = uint.MAX;
    private GLib.SequenceIter<ConversationItemModel>? last_iter;
    private unowned RowVisibilityFunc filter_func;

    private GLib.Type get_item_type () {
        return typeof (GLib.Object);
    }

    public uint get_n_items () {
        return data.get_length ();
    }

    private GLib.Object? get_item (uint index) {
        return get_item_internal (index);
    }

    private GLib.Object? get_item_internal (uint index, bool unfiltered = false) {
        GLib.SequenceIter<ConversationItemModel>? iter = null;

        if (last_position != uint.MAX) {
            if (last_position == index + 1) {
                iter = last_iter.prev ();
            } else if (last_position == index - 1) {
                iter = last_iter.next ();
            } else if (last_position == index) {
                iter = last_iter;
            }
        }

        if (iter == null) {
            iter = data.get_iter_at_pos ((int)index);
        }

        last_iter = iter;
        last_position = index;

        if (iter.is_end ()) {
            return null;
        }

        if (filter_func == null) {
            return iter.get ();
        } else if (filter_func (iter.get ())) {
            return iter.get ();
        } else if (unfiltered) {
            return iter.get ();
        } else {
            return null;
        }
    }

    public void insert_sorted (ConversationItemModel item, CompareDataFunc<Object> compare_func) {
        data.insert_sorted (item, compare_func);

        last_iter = null;
        last_position = uint.MAX;
    }

    public void remove (ConversationItemModel data) {
        var iter = this.data.get_iter_at_pos (get_index_of_unfiltered (data));
        iter.remove ();

        last_iter = null;
        last_position = uint.MAX;
    }

    public void remove_all () {
        data.get_begin_iter ().remove_range (data.get_end_iter ());
        unselect_all ();

        last_iter = null;
        last_position = uint.MAX;
    }

    public void set_filter_func (RowVisibilityFunc? function) {
        filter_func = function;
    }

    public void unselect_all () {
        selected_rows.clear ();
    }

    public void set_item_selected (GLib.Object item, bool selected) {
        if (!selected) {
            selected_rows.remove (item);
        } else {
            selected_rows.add (item);
        }
    }

    public bool get_item_selected (GLib.Object item) {
        return selected_rows.contains (item);
    }

    public Gee.ArrayList<GLib.Object> get_items_between (GLib.Object from, GLib.Object to) {
        var items = new Gee.ArrayList<GLib.Object> ();
        var start_found = false;
        var ignore_next_break = false;
        var length = get_n_items ();
        for (int i = 0; i < length; i++) {
            var item = get_item (i);
            if ((item == from || item == to) && !start_found) {
                start_found = true;
                ignore_next_break = true;
            } else if (!start_found) {
                continue;
            }

            if (item != null) {
                items.add (item);
            }

            if ((item == to || item == from) && !ignore_next_break) {
                break;
            }

            ignore_next_break = false;
        }

        return items;
    }

    public int get_index_of (GLib.Object? item) {
        if (item == null) {
            return -1;
        }

        var length = get_n_items ();
        for (int i = 0; i < length; i++) {
            if (item == get_item (i)) {
                return i;
            }
        }

        return -1;
    }

    private int get_index_of_unfiltered (GLib.Object? item) {
        if (item == null) {
            return -1;
        }

        var length = get_n_items ();
        for (int i = 0; i < length; i++) {
            if (item == get_item_internal (i, true)) {
                return i;
            }
        }

        return -1;
    }

    public int get_index_of_item_before (GLib.Object item) {
        if (item == get_item (0)) {
            return -1;
        }

        var length = get_n_items ();
        for (int i = 1; i < length; i++) {
            if (get_item (i) == item) {
                if (get_item (i - 1) != null) {
                    return i - 1;
                }
            }
        }

        return -1;
    }

    public int get_index_of_item_after (GLib.Object item) {
        if (item == get_item (get_n_items () - 1)) {
            return -1;
        }

        var length = get_n_items ();
        for (int i = 0; i < length - 1; i++) {
            if (get_item (i) == item) {
                if (get_item (i + 1) != null) {
                    return i + 1;
                }
            }
        }

        return -1;
    }

    public Gee.HashSet<weak GLib.Object> get_selected_rows () {
        return selected_rows;
    }
}
