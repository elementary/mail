// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2014-2015 Yorba Foundation
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
 */

public class ComposerHeaderbar : Gtk.HeaderBar {

    public ComposerWidget.ComposerState state { get; set; }
    public bool show_pending_attachments { get; set; default = false; }
    public bool send_enabled { get; set; default = false; }

    private Gtk.Button recipients;
    private Gtk.Label recipients_label;
    private Gtk.Button detach;

    public ComposerHeaderbar(Gtk.ActionGroup action_group) {

        detach = new Gtk.Button.from_icon_name ("window-pop-out-symbolic", Gtk.IconSize.MENU);
        detach.related_action = action_group.get_action (ComposerWidget.ACTION_DETACH);
        detach.margin_end = 6;
        detach.tooltip_text = _("Detach (Ctrl+D)");

        Gtk.Button discard = new Gtk.Button.from_icon_name ("edit-delete-symolic", Gtk.IconSize.MENU);
        discard.related_action = action_group.get_action (ComposerWidget.ACTION_CLOSE_DISCARD);
        discard.tooltip_text = _("Delete draft");

        Gtk.Button send_button = new Gtk.Button.from_icon_name ("mail-send-symbolic", Gtk.IconSize.MENU);
        send_button.related_action = action_group.get_action (ComposerWidget.ACTION_SEND);
        send_button.always_show_image = true;
        send_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        send_button.label = _("Send");
        send_button.tooltip_text = _("Send (Ctrl+Enter)");

        Gtk.Button attach = new Gtk.Button.from_icon_name ("mail-attachment-symbolic", Gtk.IconSize.MENU);
        attach.related_action = action_group.get_action (ComposerWidget.ACTION_ADD_ATTACHMENT);
        attach.tooltip_text = _("Attach file");

        Gtk.Button attach_original = new Gtk.Button.from_icon_name ("edit-copy-symbolic", Gtk.IconSize.MENU);
        attach_original.related_action = action_group.get_action (ComposerWidget.ACTION_ADD_ORIGINAL_ATTACHMENTS);
        attach_original.tooltip_text = _("Include original attachments");

        recipients = new Gtk.Button();
        recipients.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        recipients_label = new Gtk.Label (null);
        recipients_label.set_ellipsize (Pango.EllipsizeMode.END);
        recipients.add (recipients_label);
        recipients.clicked.connect (() => {
            state = ComposerWidget.ComposerState.INLINE;
        });

        bind_property ("state", recipients, "visible", BindingFlags.SYNC_CREATE, (binding, source_value, ref target_value) => {
            target_value = (state == ComposerWidget.ComposerState.INLINE_COMPACT);
            return true;
        });

        bind_property ("show-pending-attachments", attach_original, "visible", BindingFlags.SYNC_CREATE);
        bind_property ("send-enabled", send_button, "sensitive", BindingFlags.SYNC_CREATE);

        pack_start (detach);
        pack_start (attach);
        pack_start (attach_original);
        pack_start (recipients);

        pack_end (send_button);
        pack_end (discard);

        notify["state"].connect ((s, p) => {
            if (state == ComposerWidget.ComposerState.DETACHED) {
                detach.visible = false;
            }
        });
    }

    public void set_recipients (string label, string tooltip) {
        recipients_label.label = label;
        recipients.tooltip_text = tooltip;
    }
}

