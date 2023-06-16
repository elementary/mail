/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017-2023 elementary, Inc. (https://elementary.io)
 */

public class EditorToolbar : Gtk.Box {
    private const string ACTION_GROUP_PREFIX = "editor-toolbar";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    private const string ACTION_BOLD = "bold";
    private const string ACTION_ITALIC = "italic";
    private const string ACTION_UNDERLINE = "underline";
    private const string ACTION_STRIKETHROUGH = "strikethrough";
    private const string ACTION_INSERT_LINK = "insert-link";
    private const string ACTION_REMOVE_FORMAT = "remove-formatting";

    private const ActionEntry[] ACTION_ENTRIES = {
        {ACTION_BOLD, on_edit_action, "s", "''" },
        {ACTION_ITALIC, on_edit_action, "s", "''" },
        {ACTION_UNDERLINE, on_edit_action, "s", "''" },
        {ACTION_STRIKETHROUGH, on_edit_action, "s", "''" },
        {ACTION_INSERT_LINK, on_insert_link_clicked, },
        {ACTION_REMOVE_FORMAT, on_remove_format },
    };

    public Mail.WebView web_view { get; construct; }

    private SimpleActionGroup action_group;

    public EditorToolbar (Mail.WebView web_view) {
        Object (
            web_view: web_view
        );
    }

    construct {
        action_group = new SimpleActionGroup ();
        action_group.add_action_entries (ACTION_ENTRIES, this);

        unowned var application = (Gtk.Application) GLib.Application.get_default ();
        application.set_accels_for_action (ACTION_PREFIX + ACTION_INSERT_LINK, {"<Control>K"});
        application.set_accels_for_action (
            Action.print_detailed_name (ACTION_PREFIX + ACTION_STRIKETHROUGH, ACTION_STRIKETHROUGH),
            {"<Control>percent"}
        );
        application.set_accels_for_action (
            Action.print_detailed_name (ACTION_PREFIX + ACTION_UNDERLINE, ACTION_UNDERLINE),
            {"<Control>U"}
        );

        var font = new Gtk.FontButton () {
            show_style = true,
            level = FAMILY | SIZE
        };

        var bold = new Gtk.ToggleButton () {
            action_name = ACTION_PREFIX + ACTION_BOLD,
            action_target = ACTION_BOLD,
            image = new Gtk.Image.from_icon_name ("format-text-bold-symbolic", Gtk.IconSize.MENU),
            tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>B"}, _("Bold"))
        };

        var italic = new Gtk.ToggleButton () {
            action_name = ACTION_PREFIX + ACTION_ITALIC,
            action_target = ACTION_ITALIC,
            image = new Gtk.Image.from_icon_name ("format-text-italic-symbolic", Gtk.IconSize.MENU),
            tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>I"}, _("Italic"))
        };

        var underline = new Gtk.ToggleButton () {
            action_name = ACTION_PREFIX + ACTION_UNDERLINE,
            action_target = ACTION_UNDERLINE,
            image = new Gtk.Image.from_icon_name ("format-text-underline-symbolic", Gtk.IconSize.MENU),
            tooltip_markup = Granite.markup_accel_tooltip (
                application.get_accels_for_action (
                    Action.print_detailed_name (ACTION_PREFIX + ACTION_UNDERLINE, ACTION_UNDERLINE)
                ),
                _("Underline")
            )
        };

        var strikethrough = new Gtk.ToggleButton () {
            action_name = ACTION_PREFIX + ACTION_STRIKETHROUGH,
            action_target = ACTION_STRIKETHROUGH,
            image = new Gtk.Image.from_icon_name ("format-text-strikethrough-symbolic", Gtk.IconSize.MENU),
            tooltip_markup = Granite.markup_accel_tooltip (
                application.get_accels_for_action (
                    Action.print_detailed_name (ACTION_PREFIX + ACTION_STRIKETHROUGH, ACTION_STRIKETHROUGH)
                ),
                _("Strikethrough")
            )
        };

        var formatting_buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        formatting_buttons.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        formatting_buttons.add (bold);
        formatting_buttons.add (italic);
        formatting_buttons.add (underline);
        formatting_buttons.add (strikethrough);

        var clear_format = new Gtk.Button.from_icon_name ("format-text-clear-formatting-symbolic", Gtk.IconSize.MENU) {
            action_name = ACTION_PREFIX + ACTION_REMOVE_FORMAT,
            tooltip_markup = Granite.markup_accel_tooltip (
                application.get_accels_for_action (ACTION_PREFIX + ACTION_REMOVE_FORMAT),
                _("Remove formatting")
            )
        };

        var link = new Gtk.Button.from_icon_name ("insert-link-symbolic", Gtk.IconSize.MENU) {
            action_name = ACTION_PREFIX + ACTION_INSERT_LINK,
            tooltip_markup = Granite.markup_accel_tooltip (
                application.get_accels_for_action (ACTION_PREFIX + ACTION_INSERT_LINK),
                _("Insert Link")
            )
        };

        margin_start = 6;
        margin_bottom = 6;
        spacing = 6;
        orientation = HORIZONTAL;
        add (font);
        add (formatting_buttons);
        add (clear_format);
        add (link);

        map.connect (() => {
            get_toplevel ().insert_action_group (ACTION_GROUP_PREFIX, action_group);
        });

        font.font_set.connect (() => {
            var current_font = font.get_font ();
            var font_size = current_font.substring (current_font.last_index_of (" ")).replace (" ", "");
            set_font.begin (font.get_font_family ().get_name (), font_size);
        });

        web_view.selection_changed.connect (update_actions);
    }

    private async void set_font (string font_family, string font_size) {
        var selected_text = yield web_view.get_selected_text ();
        web_view.execute_editor_command (
            "insertHTML",
            """<span style="font-size:%spx;font-family:%s;">%s</span>""".printf (font_size, font_family, selected_text)
        );
        // web_view.execute_editor_command ("fontName", font_family);
        // web_view.execute_editor_command ("increaseFontSize");
    }

    private void on_insert_link_clicked () {
        ask_insert_link.begin ();
    }

    private async void ask_insert_link () {
        var selected_text = yield web_view.get_selected_text ();
        var insert_link_dialog = new InsertLinkDialog (selected_text) {
            transient_for = (Gtk.Window)get_toplevel ()
        };
        insert_link_dialog.present ();
        insert_link_dialog.insert_link.connect ((url, title) => on_link_inserted (url, title, selected_text));
    }

    private void on_link_inserted (string url, string title, string? selected_text) {
        if (selected_text != null && title == selected_text) {
            web_view.execute_editor_command ("createLink", url);
        } else {
            if (title != null && title.length > 0) {
                web_view.execute_editor_command ("insertHTML", """<a href="%s">%s</a>""".printf (url, title));
            } else {
                web_view.execute_editor_command ("insertHTML", """<a href="%s">%s</a>""".printf (url, url));
            }
        }
    }

    private void on_edit_action (SimpleAction action, Variant? param) {
        var command = param.get_string ();
        web_view.execute_editor_command (command);
        update_actions ();
    }

    private void on_remove_format () {
        web_view.execute_editor_command ("removeformat");
        web_view.execute_editor_command ("unlink");
    }

    private void update_actions () {
        web_view.query_command_state.begin ("bold", (obj, res) => {
            action_group.change_action_state (
                ACTION_BOLD,
                web_view.query_command_state.end (res) ? ACTION_BOLD : ""
            );
        });
        web_view.query_command_state.begin ("italic", (obj, res) => {
            action_group.change_action_state (
                ACTION_ITALIC,
                web_view.query_command_state.end (res) ? ACTION_ITALIC : ""
            );
        });
        web_view.query_command_state.begin ("underline", (obj, res) => {
            action_group.change_action_state (
                ACTION_UNDERLINE, web_view.query_command_state.end (res) ? ACTION_UNDERLINE : ""
            );
        });
        web_view.query_command_state.begin ("strikethrough", (obj, res) => {
            action_group.change_action_state (
                ACTION_STRIKETHROUGH,
                web_view.query_command_state.end (res) ? ACTION_STRIKETHROUGH : ""
            );
        });
    }
}
