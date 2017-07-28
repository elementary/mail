// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public class Mail.InlineComposerActions : ComposerActions {
    construct {
        container = new Gtk.Grid ();
        var content_grid = container as Gtk.Grid;
        content_grid.margin = 6;
        content_grid.column_spacing = 3;
        content_grid.hexpand = true;

        var detach = new Gtk.Button.from_icon_name ("window-pop-out-symbolic", Gtk.IconSize.MENU);
        detach.margin_end = 6;

        discard.halign = Gtk.Align.END;
        discard.hexpand = true;
        send.halign = Gtk.Align.END;

        if (content_grid != null) {
            content_grid.add (detach);
            content_grid.add (attach);
            content_grid.add (discard);
            content_grid.add (send);
        }
    }
}
