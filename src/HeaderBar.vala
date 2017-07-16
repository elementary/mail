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
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.HeaderBar : Gtk.HeaderBar {
    public Gtk.Grid paned_start_grid;
    public Gtk.SearchEntry search_entry;

    public HeaderBar () {
        Object (show_close_button: true);
    }

    construct {
        var compose_button = new Gtk.Button.from_icon_name ("mail-message-new", Gtk.IconSize.LARGE_TOOLBAR);
        compose_button.halign = Gtk.Align.START;
        compose_button.tooltip_text = _("Compose new message (Ctrl+N, N)");

        search_entry = new Gtk.SearchEntry ();
        search_entry.placeholder_text = _("Search Mail");
        search_entry.valign = Gtk.Align.CENTER;

        paned_start_grid = new Gtk.Grid ();
        paned_start_grid.add (compose_button);

        pack_start (paned_start_grid);
        pack_start (search_entry);
    }
}
