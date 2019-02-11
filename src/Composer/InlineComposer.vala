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

public class Mail.InlineComposer : Gtk.ListBoxRow {
    public signal void discarded ();

    public ComposerWidget.Type construct_type { get; construct; }
    public Camel.MessageInfo? prev_chain_info { get; construct; }
    public Camel.MimeMessage? prev_chain_message { get; construct; }
    public string? prev_message_content { get; construct; }

    private ComposerWidget composer;

    construct {
        margin = 12;

        get_style_context ().add_class ("card");

        composer = new ComposerWidget.inline ();
        composer.margin_top = 6;
        composer.has_recipients = true;
        composer.discarded.connect (() => {
            discarded ();
        });

        composer.sent.connect (() => {
            discarded ();
        });

        composer.quote_content (construct_type, prev_chain_info, prev_chain_message, prev_message_content);

        add (composer);

        map.connect (() => {
            var viewport = get_parent ().get_parent ();
            if (viewport is Gtk.Viewport) {
                height_request = viewport.get_allocated_height () - (margin * 2);
            } else {
                height_request = 200;
            }
        });

        show_all ();
    }

    public InlineComposer (ComposerWidget.Type type, Camel.MessageInfo info, Camel.MimeMessage message, string? content) {
        Object (
            construct_type: type,
            prev_chain_info: info,
            prev_chain_message: message,
            prev_message_content: content
        );
    }
}
