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
    private GLib.Sequence<ConversationItemModel> data = new GLib.Sequence<ConversationItemModel> ();
    private uint last_position = -1u;
    private GLib.SequenceIter<ConversationItemModel>? last_iter;
    private unowned GLib.CompareDataFunc<ConversationItemModel> compare_func;

	public override uint get_n_items () {
		return data.get_length ();
	}

	public override GLib.Object? get_item (uint index) {
	    GLib.SequenceIter<ConversationItemModel>? iter = null;

	    if (last_position != -1u) {
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

	    return iter.get ();
	}

	public void add (ConversationItemModel data) {
	    if (compare_func != null) {
	        this.data.insert_sorted (data, compare_func);
	    } else {
    	    this.data.append (data);
	    }

	    last_iter = null;
	    last_position = -1u;
	}

	public void remove (ConversationItemModel data) {
	    var iter = this.data.get_iter_at_pos (get_index_of (data));
	    iter.remove ();

	    last_iter = null;
	    last_position = -1u;
	}

	public void remove_all () {
	    data.get_begin_iter ().remove_range (data.get_end_iter ());
	    unselect_all ();

	    last_iter = null;
        last_position = -1u;
	}

	public void set_sort_func (GLib.CompareDataFunc<ConversationItemModel> function) {
	    this.compare_func = function;
	}
}
