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
    private Gtk.ToggleButton bold;
    private Gtk.ToggleButton italic;
    private Gtk.ToggleButton underline;
    private Gtk.ToggleButton strikethrough;
    private Gtk.Button link;
    private Gtk.Button clear_format;

    public ComposerToolbar (Gtk.Menu menu) {
        hexpand = true;
        spacing = 6;

        // Font formatting
        var formatting = new Gtk.Grid ();
        formatting.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);

        bold = new Gtk.ToggleButton ();
        bold.set_action_name (ComposerWidget.ACTION_GROUP_PREFIX + ComposerWidget.ACTION_BOLD);
        bold.tooltip_text = _("Bold (Ctrl+B)");
        bold.image = new Gtk.Image.from_icon_name ("format-text-bold-symbolic", Gtk.IconSize.MENU);

        italic = new Gtk.ToggleButton ();
        italic.set_action_name (ComposerWidget.ACTION_GROUP_PREFIX + ComposerWidget.ACTION_ITALIC);
        italic.tooltip_text = _("Italic (Ctrl+I)");
        italic.image = new Gtk.Image.from_icon_name ("format-text-italic-symbolic", Gtk.IconSize.MENU);

        underline = new Gtk.ToggleButton ();
        underline.set_action_name (ComposerWidget.ACTION_GROUP_PREFIX + ComposerWidget.ACTION_UNDERLINE);
        underline.tooltip_text = _("Underline (Ctrl+U)");
        underline.image = new Gtk.Image.from_icon_name ("format-text-underline-symbolic", Gtk.IconSize.MENU);

        strikethrough = new Gtk.ToggleButton ();
        strikethrough.set_action_name (ComposerWidget.ACTION_GROUP_PREFIX + ComposerWidget.ACTION_STRIKETHROUGH);
        strikethrough.tooltip_text = _("Strikethrough (Ctrl+%)");
        strikethrough.image = new Gtk.Image.from_icon_name ("format-text-strikethrough-symbolic", Gtk.IconSize.MENU);

        formatting.add (bold);
        formatting.add (italic);
        formatting.add (underline);
        formatting.add (strikethrough);

        // Indent level.
        var indent = new Gtk.Grid ();
        indent.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);

        var indent_more = new Gtk.Button.from_icon_name ("format-indent-more-symbolic", Gtk.IconSize.MENU);
        indent_more.set_action_name (ComposerWidget.ACTION_GROUP_PREFIX + ComposerWidget.ACTION_INDENT);
        indent_more.tooltip_text = _("Quote text (Ctrl+])");

        var indent_less = new Gtk.Button.from_icon_name ("format-indent-less-symbolic", Gtk.IconSize.MENU);
        indent_less.set_action_name (ComposerWidget.ACTION_GROUP_PREFIX + ComposerWidget.ACTION_OUTDENT);
        indent_less.tooltip_text = _("Unquote text (Ctrl+[)");

        indent.add (indent_more);
        indent.add (indent_less);

        // Link
        link = new Gtk.Button.from_icon_name ("insert-link-symbolic", Gtk.IconSize.MENU);
        link.set_action_name (ComposerWidget.ACTION_GROUP_PREFIX + ComposerWidget.ACTION_INSERT_LINK);
        link.tooltip_text = _("Link (Ctrl+K)");

        // Clear formatting.
        clear_format = new Gtk.Button.from_icon_name ("format-text-clear-formatting-symbolic", Gtk.IconSize.MENU);
        clear_format.set_action_name (ComposerWidget.ACTION_GROUP_PREFIX + ComposerWidget.ACTION_REMOVE_FORMAT);
        clear_format.tooltip_text = _("Remove formatting (Ctrl+Space)");

        // Menu.
        var more = new Gtk.MenuButton ();
        more.image = new Gtk.Image.from_icon_name ("view-more-symbolic", Gtk.IconSize.MENU);
        more.popup = menu;
        more.tooltip_text = _("More options");

        var label = new Gtk.Label (null);
        label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        bind_property ("label-text", label, "label", BindingFlags.SYNC_CREATE);

        add (formatting);
        add (indent);
        add (link);
        add (clear_format);
        pack_end (more, false, false, 0);
        pack_end (label, false, false, 0);
    }

    public void set_html_buttons_visible (bool visible) {
        bold.visible =
            italic.visible =
            underline.visible =
            strikethrough.visible =
            link.visible =
            clear_format.visible = visible;
    }
}

