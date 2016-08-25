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
    private ComposerWidget composer;
    private bool has_accel_group = false;

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

    public Gtk.Window top_window {
        get {
            return get_toplevel () as Gtk.Window;
        }
    }

    public void present () {
        
    }

    public unowned Gtk.Widget get_focus () {
        return top_window.get_focus ();
    }

    // Depending on the ComposerCard having the focus, the shortcuts for the buttons in the
    // ComposerToolbar (Bold, Italic, Underline, ...) are active. This would allow the same
    // shortcuts defined for the ComposerCard and the MainToolbar.
    private bool on_focus_in () {
        // For some reason, on_focus_in gets called a bunch upon construction.
        if (!has_accel_group)
            top_window.add_accel_group (composer.ui.get_accel_group ());
        has_accel_group = true;
        return false;
    }
    
    // If there is no ComposerCard opened, the shortcuts for the buttons in the MainToolbar
    // (mark as read, mark as unread, forward email, ...) are active. This would allow the same
    // shortcuts defined for the ComposerCard and the MainToolbar.
    private bool on_focus_out () {
        top_window.remove_accel_group (composer.ui.get_accel_group ());
        has_accel_group = false;
        return false;
    }

    public void vanish () {
        hide ();
        composer.editor.focus_in_event.disconnect (on_focus_in);
        composer.editor.focus_out_event.disconnect (on_focus_out);
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
        composer.editor.focus_in_event.disconnect (on_focus_in);
        composer.editor.focus_out_event.disconnect (on_focus_out);
        close_container ();
    }
}
