// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2011-2015 Yorba Foundation
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

public class ComposerToolbar : Gtk.Box {

    public string label_text { get; set; }

    public ComposerToolbar (Gtk.ActionGroup toolbar_action_group, Gtk.Menu menu) {
        hexpand = true;
        spacing = 6;

        // Font formatting
        Gtk.Grid formatting = new Gtk.Grid ();
        formatting.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);

        Gtk.ToggleButton bold = new Gtk.ToggleButton ();
        bold.related_action = toolbar_action_group.get_action (ComposerWidget.ACTION_BOLD);
        bold.tooltip_text = _("Bold (Ctrl+B)");
        bold.image = new Gtk.Image.from_icon_name ("format-text-bold-symbolic", Gtk.IconSize.MENU);

        Gtk.ToggleButton italic = new Gtk.ToggleButton ();
        italic.related_action = toolbar_action_group.get_action (ComposerWidget.ACTION_ITALIC);
        italic.tooltip_text = _("Italic (Ctrl+I)");
        italic.image = new Gtk.Image.from_icon_name ("format-text-italic-symbolic", Gtk.IconSize.MENU);

        Gtk.ToggleButton underline = new Gtk.ToggleButton ();
        underline.related_action = toolbar_action_group.get_action (ComposerWidget.ACTION_UNDERLINE);
        underline.tooltip_text = _("Underline (Ctrl+U)");
        underline.image = new Gtk.Image.from_icon_name ("format-text-underline-symbolic", Gtk.IconSize.MENU);

        Gtk.ToggleButton strikethrough = new Gtk.ToggleButton ();
        strikethrough.related_action = toolbar_action_group.get_action (ComposerWidget.ACTION_STRIKETHROUGH);
        strikethrough.tooltip_text = _("Strikethrough (Ctrl+K)");
        strikethrough.image = new Gtk.Image.from_icon_name ("format-text-strikethrough-symbolic", Gtk.IconSize.MENU);

        formatting.add (bold);
        formatting.add (italic);
        formatting.add (underline);
        formatting.add (strikethrough);

        // Indent level.
        Gtk.Grid indent = new Gtk.Grid ();
        indent.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);

        Gtk.Button indent_more = new Gtk.Button.from_icon_name ("format-indent-more-symbolic", Gtk.IconSize.MENU);
        indent_more.related_action = toolbar_action_group.get_action (ComposerWidget.ACTION_INDENT);
        indent_more.tooltip_text = _("Quote text (Ctrl+])");

        Gtk.Button indent_less = new Gtk.Button.from_icon_name ("format-indent-less-symbolic", Gtk.IconSize.MENU);
        indent_less.related_action = toolbar_action_group.get_action (ComposerWidget.ACTION_OUTDENT);
        indent_less.tooltip_text = _("Unquote text (Ctrl+[)");

        indent.add (indent_more);
        indent.add (indent_less);

        // Link
        Gtk.Button link = new Gtk.Button.from_icon_name ("insert-link-symbolic", Gtk.IconSize.MENU);
        link.related_action = toolbar_action_group.get_action (ComposerWidget.ACTION_INSERT_LINK);
        link.tooltip_text = _("Link (Ctrl+L)");

        // Clear formatting.
        Gtk.Button clear_format = new Gtk.Button.from_icon_name ("format-text-clear-formatting-symbolic", Gtk.IconSize.MENU);
        clear_format.related_action = toolbar_action_group.get_action (ComposerWidget.ACTION_REMOVE_FORMAT);
        clear_format.tooltip_text = _("Remove formatting (Ctrl+Space)");

        // Menu.
        Gtk.MenuButton more = new Gtk.MenuButton ();
        more.image = new Gtk.Image.from_icon_name ("view-more-symbolic", Gtk.IconSize.MENU);
        more.popup = menu;
        more.tooltip_text = _("More options");

        Gtk.Label label = new Gtk.Label (null);
        label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        bind_property ("label-text", label, "label", BindingFlags.SYNC_CREATE);

        add (formatting);
        add (indent);
        add (link);
        add (clear_format);
        pack_end (more, false, false, 0);
        pack_end (label, false, false, 0);
    }
}

