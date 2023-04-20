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
    /* The items_changed signal is not emitted automatically, the object using this has to emit it manually */

    private GLib.List<ConversationItemModel> data = new GLib.List<ConversationItemModel> ();

    public GLib.Type get_item_type () {
        return typeof (ConversationItemModel);
    }

    public uint get_n_items () {
        uint n_items = 0;
        data.foreach ((item) => {
            n_items++;
        });
        return n_items;
    }

    public GLib.Object? get_item (uint index) {
        return get_item_internal (index);
    }

    private ConversationItemModel get_item_internal (uint index) {
        return data.nth_data (index);
    }

    public void add (ConversationItemModel item) {
        /* Adding automatically sorts according to timestamp */
        data.insert_sorted (item, (a, b)=> {
            var item1 = (ConversationItemModel) a;
            var item2 = (ConversationItemModel) b;
            return (int)(item2.timestamp - item1.timestamp);
        });
    }

    public void remove_all () {
        data.foreach ((item) => {
            data.remove (item);
        });
    }

    public void remove (ConversationItemModel item) {
        data.remove (item);
    }
}
