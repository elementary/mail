// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016 elementary LLC.
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class ComposerCard : Gtk.ListBoxRow, ComposerContainer {
    internal ComposerWidget composer { get; set; }
    protected Gee.MultiMap<string, string>? old_accelerators { get; set; }

    public ComposerCard (ComposerWidget composer) {
        this.composer = composer;
        add (composer);
        composer.editor.focus_in_event.connect (on_focus_in);
        composer.editor.focus_out_event.connect (on_focus_out);
        show_all ();
        present ();
    }

    construct {
        margin = 12;
        margin_top = 0;
        get_style_context ().add_class ("card");
    }

    public Gtk.ApplicationWindow top_window {
        get {
            return get_toplevel () as Gtk.ApplicationWindow;
        }
    }

    public void present () {
        
    }

    public unowned Gtk.Widget get_focus () {
        return top_window.get_focus ();
    }

    public void vanish () {
        hide ();
        composer.state = ComposerWidget.ComposerState.DETACHED;
    }

    public void close_container () {
        if (visible) {
            vanish ();
        }

        destroy();
    }

    public void remove_composer () {
        composer.parent.remove (composer);
        close_container ();
    }
}
