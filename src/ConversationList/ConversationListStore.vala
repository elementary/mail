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

public class Mail.ConversationListStore : VirtualizingListBoxModel {
    public delegate bool RowVisibilityFunc (GLib.Object row);

    private GLib.Sequence<ConversationItemModel> data = new GLib.Sequence<ConversationItemModel> ();
    private uint last_position = uint.MAX;
    private GLib.SequenceIter<ConversationItemModel>? last_iter;
    private unowned GLib.CompareDataFunc<ConversationItemModel> compare_func;
    private unowned RowVisibilityFunc filter_func;

    public override uint get_n_items () {
        uint data_length = 0;
        lock (data) {
            data_length = data.get_length ();
        }
        return data_length;
    }

    public override GLib.Object? get_item (uint index) {
        return get_item_internal (index);
    }

    public override GLib.Object? get_item_unfiltered (uint index) {
        return get_item_internal (index, true);
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
            lock (data) {
                iter = data.get_iter_at_pos ((int)index);
            }
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

    public void add (ConversationItemModel data) {
        lock (this.data) {
            if (compare_func != null) {
                this.data.insert_sorted (data, compare_func);
            } else {
                this.data.append (data);
            }
        }

        last_iter = null;
        last_position = uint.MAX;
    }

    public void remove (ConversationItemModel data) {
        lock (this.data) {
            var iter = this.data.get_iter_at_pos (get_index_of_unfiltered (data));
            iter.remove ();
        }

        last_iter = null;
        last_position = uint.MAX;
    }

    public void remove_all () {
        lock (data) {
            data.get_begin_iter ().remove_range (data.get_end_iter ());
        }
        unselect_all ();

        last_iter = null;
        last_position = uint.MAX;
    }

    public void set_sort_func (GLib.CompareDataFunc<ConversationItemModel> function) {
        this.compare_func = function;
    }

    public void set_filter_func (RowVisibilityFunc function) {
        filter_func = function;
    }
}
