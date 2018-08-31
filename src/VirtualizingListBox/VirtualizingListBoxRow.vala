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

public class VirtualizingListBoxRow<T> : Gtk.Bin {
    public bool selectable { get; set; default = true; }
    public weak T model_item { get; set; }

    static construct {
        set_css_name ("row");
    }

    construct {
        can_focus = true;
        set_redraw_on_allocate (true);

        get_style_context ().add_class ("activatable");
    }

    public override bool draw (Cairo.Context ct) {
        var sc = this.get_style_context ();
		Gtk.Allocation alloc;
		this.get_allocation (out alloc);

		sc.render_background (ct, 0, 0, alloc.width, alloc.height);
		sc.render_frame      (ct, 0, 0, alloc.width, alloc.height);

        return base.draw (ct);
    }
}
