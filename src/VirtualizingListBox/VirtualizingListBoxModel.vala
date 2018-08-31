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

public abstract class VirtualizingListBoxModel<T> : GLib.ListModel, GLib.Object {
    private Gee.HashSet<weak T> selected_rows = new Gee.HashSet<weak T> ();

	public GLib.Type get_item_type () {
		return typeof (T);
	}

	public abstract uint get_n_items ();
	public abstract GLib.Object? get_item (uint index);

	public void unselect_all () {
	    selected_rows.clear ();
	}

	public void set_item_selected (T item, bool selected) {
        if (!selected) {
            selected_rows.remove (item);
        } else {
            selected_rows.add (item);
        }
	}

	public bool get_item_selected (T item) {
	    return selected_rows.contains (item);
	}

	public Gee.ArrayList<T> get_items_between (T from, T to) {
	    var items = new Gee.ArrayList<T> ();
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

	        items.add (item);

	        if ((item == to || item == from) && !ignore_next_break) {
	            break;
	        }

	        ignore_next_break = false;
	    }

	    return items;
	}

	public int get_index_of (T? item) {
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

	public int get_index_of_item_before (T item) {
	    if (item == get_item(0)) {
	        return -1;
	    }

        var length = get_n_items ();
	    for (int i = 1; i < length; i++) {
	        if (get_item (i) == item) {
	            return i - 1;
	        }
	    }

	    return -1;
	}

	public int get_index_of_item_after (T item) {
	    if (item == get_item (get_n_items () - 1)) {
	        return -1;
	    }

        var length = get_n_items ();
	    for (int i = 0; i < length - 1; i++) {
	        if (get_item (i) == item) {
	            return i + 1;
	        }
	    }

	    return -1;
	}
}
