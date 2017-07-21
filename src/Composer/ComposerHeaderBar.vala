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

public class Mail.ComposerHeaderBar : Gtk.HeaderBar {

    public ComposerHeaderBar () {
        Object (
            show_close_button: true,
            title: _("New Message")
        );
    }

    construct {
        var discard = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.MENU);
        discard.tooltip_text = _("Delete draft");

        var send_button = new Gtk.Button.from_icon_name ("mail-send-symbolic", Gtk.IconSize.MENU);
        send_button.always_show_image = true;
        send_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        send_button.label = _("Send");
        send_button.tooltip_text = _("Send (Ctrl+Enter)");

        var attach = new Gtk.Button.from_icon_name ("mail-attachment-symbolic", Gtk.IconSize.MENU);
        attach.tooltip_text = _("Attach file");

        pack_start (attach);

        pack_end (send_button);
        pack_end (discard);
    }
}

