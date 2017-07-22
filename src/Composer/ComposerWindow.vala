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

    public ComposerWindow () {
        Object (
            height_request: 600,
            title: _("New Message"),
            width_request: 680
        );
    }

    construct {
        var to_label = new Gtk.Label (_("To:"));
        to_label.halign = Gtk.Align.END;
        to_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var cc_label = new Gtk.Label (_("Cc:"));
        cc_label.halign = Gtk.Align.END;
        cc_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var subject_label = new Gtk.Label (_("Subject:"));
        subject_label.halign = Gtk.Align.END;
        subject_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var to_val = new Gtk.Entry ();
        to_val.hexpand = true;

        var cc_val = new Gtk.Entry ();
        cc_val.hexpand = true;

        var subject_val = new Gtk.Entry ();
        subject_val.hexpand = true;

        var recipient_grid = new Gtk.Grid ();
        recipient_grid.margin = 6;
        recipient_grid.margin_top = 12;
        recipient_grid.column_spacing = 6;
        recipient_grid.row_spacing = 6;
        recipient_grid.attach (to_label, 0, 0, 1, 1);
        recipient_grid.attach (to_val, 1, 0, 1, 1);
        recipient_grid.attach (cc_label, 0, 1, 1, 1);
        recipient_grid.attach (cc_val, 1, 1, 1, 1);
        recipient_grid.attach (subject_label, 0, 2, 1, 1);
        recipient_grid.attach (subject_val, 1, 2, 1, 1);

        var bold = new Gtk.ToggleButton ();
        bold.tooltip_text = _("Bold (Ctrl+B)");
        bold.image = new Gtk.Image.from_icon_name ("format-text-bold-symbolic", Gtk.IconSize.MENU);

        var italic = new Gtk.ToggleButton ();
        italic.tooltip_text = _("Italic (Ctrl+I)");
        italic.image = new Gtk.Image.from_icon_name ("format-text-italic-symbolic", Gtk.IconSize.MENU);

        var underline = new Gtk.ToggleButton ();
        underline.tooltip_text = _("Underline (Ctrl+U)");
        underline.image = new Gtk.Image.from_icon_name ("format-text-underline-symbolic", Gtk.IconSize.MENU);

        var strikethrough = new Gtk.ToggleButton ();
        strikethrough.tooltip_text = _("Strikethrough (Ctrl+%)");
        strikethrough.image = new Gtk.Image.from_icon_name ("format-text-strikethrough-symbolic", Gtk.IconSize.MENU);

        var formatting_buttons = new Gtk.Grid ();
        formatting_buttons.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        formatting_buttons.add (bold);
        formatting_buttons.add (italic);
        formatting_buttons.add (underline);
        formatting_buttons.add (strikethrough);

        var indent_more = new Gtk.Button.from_icon_name ("format-indent-more-symbolic", Gtk.IconSize.MENU);
        indent_more.tooltip_text = _("Quote text (Ctrl+])");

        var indent_less = new Gtk.Button.from_icon_name ("format-indent-less-symbolic", Gtk.IconSize.MENU);
        indent_less.tooltip_text = _("Unquote text (Ctrl+[)");

        var indent_buttons = new Gtk.Grid ();
        indent_buttons.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        indent_buttons.add (indent_more);
        indent_buttons.add (indent_less);

        var link = new Gtk.Button.from_icon_name ("insert-link-symbolic", Gtk.IconSize.MENU);
        link.tooltip_text = _("Link (Ctrl+K)");

        var image = new Gtk.Button.from_icon_name ("insert-image-symbolic", Gtk.IconSize.MENU);
        image.tooltip_text = _("Image (Ctrl+G)");

        var clear_format = new Gtk.Button.from_icon_name ("format-text-clear-formatting-symbolic", Gtk.IconSize.MENU);
        clear_format.tooltip_text = _("Remove formatting (Ctrl+Space)");

        var button_row = new Gtk.Grid ();
        button_row.column_spacing = 6;
        button_row.margin_left = 6;
        button_row.margin_bottom = 6;
        button_row.add (formatting_buttons);
        button_row.add (indent_buttons);
        button_row.add (link);
        button_row.add (image);
        button_row.add (clear_format);

        var web_view = new WebView ();
        web_view.editable = true;

        var discard = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.MENU);
        discard.margin_start = 6;
        discard.tooltip_text = _("Delete draft");

        var attach = new Gtk.Button.from_icon_name ("mail-attachment-symbolic", Gtk.IconSize.MENU);
        attach.tooltip_text = _("Attach file");

        var send_button = new Gtk.Button.from_icon_name ("mail-send-symbolic", Gtk.IconSize.MENU);
        send_button.always_show_image = true;
        send_button.label = _("Send");
        send_button.margin = 6;
        send_button.tooltip_text = _("Send (Ctrl+Enter)");
        send_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var action_bar = new Gtk.ActionBar ();
        action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
        action_bar.pack_start (discard);
        action_bar.pack_start (attach);
        action_bar.pack_end (send_button);

        var content_grid = new Gtk.Grid ();
        content_grid.orientation = Gtk.Orientation.VERTICAL;
        content_grid.add (recipient_grid);
        content_grid.add (button_row);
        content_grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        content_grid.add (web_view);
        content_grid.add (action_bar);

        get_style_context ().add_class ("rounded");
        add (content_grid);
    }
}
