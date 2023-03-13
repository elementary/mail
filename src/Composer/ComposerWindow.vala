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

public class Mail.ComposerWindow : Gtk.ApplicationWindow {

    public ComposerWidget composer_widget { get; construct; }

    public ComposerWindow (Gtk.Window parent, string? to = null, string? mailto_query = null) {
        Object (
            transient_for: parent,
            composer_widget: new ComposerWidget.with_headers (to, mailto_query)
        );
    }

    public ComposerWindow.for_widget (Gtk.Window parent, ComposerWidget composer_widget) {
        Object (
            transient_for: parent,
            composer_widget: composer_widget
        );
    }

    construct {
        var titlebar = new Gtk.HeaderBar () {
            title_widget = new Gtk.Label (_("New Message"))
        };
        titlebar.add_css_class ("default-decoration"); //@TODO: test: works?

        composer_widget.discarded.connect (() => {
            close ();
        });
        composer_widget.sent.connect (() => {
            close ();
        });
        composer_widget.subject_changed.connect ((subject) => {
            if (subject == null || subject.length == 0) {
                subject = _("New Message");
            }

            ((Gtk.Label) titlebar.get_title_widget ()).label = title = subject;
        });

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        content_box.append (titlebar);
        content_box.append (composer_widget);

        height_request = 600;
        width_request = 680;
        title = _("New Message");
        //window_position = Gtk.WindowPosition.CENTER_ON_PARENT; @TODO: lookup how thats gonna work

        set_child (content_box);
    }
}
