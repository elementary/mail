/* Copyright 2011-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class ComposerToolbar : PillToolbar {

    public string label_text { get; set; }

    public ComposerToolbar(Gtk.ActionGroup toolbar_action_group, Gtk.Menu menu) {
        base(toolbar_action_group);

        Gee.List<Gtk.Button> insert = new Gee.ArrayList<Gtk.Button>();

        // Font formatting
        Gtk.Grid formatting = new Gtk.Grid ();
        formatting.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);

        Gtk.ToggleButton bold = new Gtk.ToggleButton ();
        bold.related_action = toolbar_action_group.get_action (ComposerWidget.ACTION_BOLD);
        bold.tooltip_text = bold.related_action.tooltip;
        bold.image = new Gtk.Image.from_icon_name ("format-text-bold-symbolic", Gtk.IconSize.MENU);

        Gtk.ToggleButton italic = new Gtk.ToggleButton ();
        italic.related_action = toolbar_action_group.get_action (ComposerWidget.ACTION_ITALIC);
        italic.tooltip_text = italic.related_action.tooltip;
        italic.image = new Gtk.Image.from_icon_name ("format-text-italic-symbolic", Gtk.IconSize.MENU);

        Gtk.ToggleButton underline = new Gtk.ToggleButton ();
        underline.related_action = toolbar_action_group.get_action (ComposerWidget.ACTION_UNDERLINE);
        underline.tooltip_text = underline.related_action.tooltip;
        underline.image = new Gtk.Image.from_icon_name ("format-text-underline-symbolic", Gtk.IconSize.MENU);

        Gtk.ToggleButton strikethrough = new Gtk.ToggleButton ();
        strikethrough.related_action = toolbar_action_group.get_action (ComposerWidget.ACTION_STRIKETHROUGH);
        strikethrough.tooltip_text = strikethrough.related_action.tooltip;
        strikethrough.image = new Gtk.Image.from_icon_name ("format-text-strikethrough-symbolic", Gtk.IconSize.MENU);

        formatting.add (bold);
        formatting.add (italic);
        formatting.add (underline);
        formatting.add (strikethrough);
        add (formatting);

        // Indent level.
        insert.clear();
        insert.add(create_toolbar_button(null, ComposerWidget.ACTION_INDENT));
        insert.add(create_toolbar_button(null, ComposerWidget.ACTION_OUTDENT));
        pack_start (create_pill_buttons(insert, false), false, false, 0);

        // Link.
        insert.clear();
        insert.add(create_toolbar_button(null, ComposerWidget.ACTION_INSERT_LINK));
        pack_start (create_pill_buttons(insert), false, false, 0);

        // Remove formatting.
        insert.clear();
        insert.add(create_toolbar_button(null, ComposerWidget.ACTION_REMOVE_FORMAT));
        pack_start (create_pill_buttons(insert), false, false, 0);

        // Menu.
        Gtk.MenuButton more = new Gtk.MenuButton();
        more.image = new Gtk.Image.from_icon_name("view-more-symbolic", Gtk.IconSize.MENU);
        more.popup = menu;
        more.tooltip_text = _("More options");
        pack_end (more, false, false, 0);

        Gtk.Label label = new Gtk.Label(null);
        label.get_style_context().add_class("dim-label");
        bind_property("label-text", label, "label", BindingFlags.SYNC_CREATE);
        pack_end (label, false, false, 0);
    }
}

