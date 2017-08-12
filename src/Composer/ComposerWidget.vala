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

public class Mail.ComposerWidget : Gtk.Grid {
    public signal void discarded ();

    private const string ACTION_GROUP_PREFIX = "composer";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    private const string ACTION_BOLD = "bold";
    private const string ACTION_ITALIC = "italic";
    private const string ACTION_UNDERLINE = "underline";
    private const string ACTION_STRIKETHROUGH = "strikethrough";
    private const string ACTION_REMOVE_FORMAT = "remove_formatting";
    private const string ACTION_DISCARD = "discard";

    public bool has_subject_field { get; construct; }

    private WebView web_view;
    private SimpleActionGroup actions;
    private Gtk.Button send;

    public const ActionEntry[] action_entries = {
        {ACTION_BOLD,           on_edit_action,    "s",    "''"     },
        {ACTION_ITALIC,         on_edit_action,    "s",    "''"     },
        {ACTION_UNDERLINE,      on_edit_action,    "s",    "''"     },
        {ACTION_STRIKETHROUGH,  on_edit_action,    "s",    "''"     },
        {ACTION_REMOVE_FORMAT,  on_remove_format                    },
        {ACTION_DISCARD,        on_discard                          }
    };

    private bool _has_recipients;
    public bool has_recipients {
        get {
            return _has_recipients;
        }
        set {
            _has_recipients = value;
            send.sensitive = has_recipients;
        }
    }

    public ComposerWidget () {
        Object (has_subject_field: false);
    }

    public ComposerWidget.with_subject () {
        Object (has_subject_field: true);
    }

    construct {
        actions = new SimpleActionGroup ();
        actions.add_action_entries (action_entries, this);
        insert_action_group (ACTION_GROUP_PREFIX, actions);

        var to_label = new Gtk.Label (_("To:"));
        to_label.xalign = 1;
        to_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var subject_label = new Gtk.Label (_("Subject:"));
        subject_label.xalign = 1;
        subject_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var to_val = new Gtk.Entry ();
        to_val.hexpand = true;

        var cc_button = new Gtk.ToggleButton.with_label (_("Cc"));

        var bcc_button = new Gtk.ToggleButton.with_label (_("Bcc"));

        var to_grid = new Gtk.Grid ();
        to_grid.add (to_val);
        to_grid.add (cc_button);
        to_grid.add (bcc_button);

        var to_grid_style_context = to_grid.get_style_context ();
        to_grid_style_context.add_class (Gtk.STYLE_CLASS_ENTRY);

        var cc_label = new Gtk.Label (_("Cc:"));
        cc_label.xalign = 1;
        cc_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var cc_val = new Gtk.Entry ();
        cc_val.hexpand = true;

        var cc_grid = new Gtk.Grid ();
        cc_grid.column_spacing = 6;
        cc_grid.margin_top = 6;
        cc_grid.add (cc_label);
        cc_grid.add (cc_val);

        var cc_revealer = new Gtk.Revealer ();
        cc_revealer.add (cc_grid);

        var bcc_label = new Gtk.Label (_("Bcc:"));
        bcc_label.xalign = 1;
        bcc_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var bcc_val = new Gtk.Entry ();
        bcc_val.hexpand = true;

        var bcc_grid = new Gtk.Grid ();
        bcc_grid.column_spacing = 6;
        bcc_grid.margin_top = 6;
        bcc_grid.add (bcc_label);
        bcc_grid.add (bcc_val);

        var bcc_revealer = new Gtk.Revealer ();
        bcc_revealer.add (bcc_grid);

        var subject_val = new Gtk.Entry ();
        subject_val.margin_top = 6;

        var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
        size_group.add_widget (to_label);
        size_group.add_widget (cc_label);
        size_group.add_widget (bcc_label);
        size_group.add_widget (subject_label);

        var recipient_grid = new Gtk.Grid ();
        recipient_grid.margin = 6;
        recipient_grid.margin_top = 12;
        recipient_grid.column_spacing = 6;
        recipient_grid.attach (to_label, 0, 0, 1, 1);
        recipient_grid.attach (to_grid, 1, 0, 1, 1);
        recipient_grid.attach (cc_revealer, 0, 1, 2, 1);
        recipient_grid.attach (bcc_revealer, 0, 2, 2, 1);
        if (has_subject_field) {
            recipient_grid.attach (subject_label, 0, 3, 1, 1);
            recipient_grid.attach (subject_val, 1, 3, 1, 1);
        }

        var bold = new Gtk.ToggleButton ();
        bold.tooltip_text = _("Bold (Ctrl+B)");
        bold.image = new Gtk.Image.from_icon_name ("format-text-bold-symbolic", Gtk.IconSize.MENU);
        bold.action_name = ACTION_PREFIX + ACTION_BOLD;
        bold.action_target = ACTION_BOLD;

        var italic = new Gtk.ToggleButton ();
        italic.tooltip_text = _("Italic (Ctrl+I)");
        italic.image = new Gtk.Image.from_icon_name ("format-text-italic-symbolic", Gtk.IconSize.MENU);
        italic.action_name = ACTION_PREFIX + ACTION_ITALIC;
        italic.action_target = ACTION_ITALIC;

        var underline = new Gtk.ToggleButton ();
        underline.tooltip_text = _("Underline (Ctrl+U)");
        underline.image = new Gtk.Image.from_icon_name ("format-text-underline-symbolic", Gtk.IconSize.MENU);
        underline.action_name = ACTION_PREFIX + ACTION_UNDERLINE;
        underline.action_target = ACTION_UNDERLINE;

        var strikethrough = new Gtk.ToggleButton ();
        strikethrough.tooltip_text = _("Strikethrough (Ctrl+%)");
        strikethrough.image = new Gtk.Image.from_icon_name ("format-text-strikethrough-symbolic", Gtk.IconSize.MENU);
        strikethrough.action_name = ACTION_PREFIX + ACTION_STRIKETHROUGH;
        strikethrough.action_target = ACTION_STRIKETHROUGH;

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
        clear_format.action_name = ACTION_PREFIX + ACTION_REMOVE_FORMAT;

        var button_row = new Gtk.Grid ();
        button_row.column_spacing = 6;
        button_row.margin_left = 6;
        button_row.margin_bottom = 6;
        button_row.add (formatting_buttons);
        button_row.add (indent_buttons);
        button_row.add (link);
        button_row.add (image);
        button_row.add (clear_format);

        web_view = new WebView ();
        try {
            var template = resources_lookup_data ("/io/elementary/mail/blank-message-template.html", ResourceLookupFlags.NONE);
            var template_html = (string)Bytes.unref_to_data (template);
            web_view.load_html (template_html);
        } catch (Error e) {
            warning ("Failed to load blank message template: %s", e.message);
        }

        web_view.selection_changed.connect (update_actions);

        var action_bar = new Gtk.ActionBar ();

        var discard = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.MENU);
        discard.margin_start = 6;
        discard.tooltip_text = _("Delete draft");
        discard.action_name = ACTION_PREFIX + ACTION_DISCARD;

        var attach = new Gtk.Button.from_icon_name ("mail-attachment-symbolic", Gtk.IconSize.MENU);
        attach.tooltip_text = _("Attach file");

        send = new Gtk.Button.from_icon_name ("mail-send-symbolic", Gtk.IconSize.MENU);
        send.margin = 6;
        send.sensitive = false;
        send.always_show_image = true;
        send.label = _("Send");
        send.tooltip_text = _("Send (Ctrl+Enter)");
        send.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);

        action_bar.pack_start (discard);
        action_bar.pack_start (attach);
        action_bar.pack_end (send);

        orientation = Gtk.Orientation.VERTICAL;
        add (recipient_grid);
        add (button_row);
        add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        add (web_view);
        add (action_bar);

        var contact_manager = ContactManager.get_default ();
        contact_manager.setup_entry (to_val);
        contact_manager.setup_entry (cc_val);
        contact_manager.setup_entry (bcc_val);

        cc_button.clicked.connect (() => {
            cc_revealer.reveal_child = cc_button.active;
        });

        cc_val.changed.connect (() => {
            if (cc_val.text == "") {
                cc_button.sensitive = true;
            } else {
                cc_button.sensitive = false;
            }
        });

        bcc_button.clicked.connect (() => {
            bcc_revealer.reveal_child = bcc_button.active;
        });

        bcc_val.changed.connect (() => {
            if (bcc_val.text == "") {
                bcc_button.sensitive = true;
            } else {
                bcc_button.sensitive = false;
            }
        });

        to_val.changed.connect (() => {
            has_recipients = to_val.text != "";
        });

        to_val.get_style_context ().changed.connect (() => {
            var state = to_grid_style_context.get_state ();
            if (to_val.has_focus) {
                state |= Gtk.StateFlags.FOCUSED;
            } else {
                state ^= Gtk.StateFlags.FOCUSED;
            }

            to_grid_style_context.set_state (state);
        });
    }

    public void quote_content (Camel.MessageInfo message, string? content_to_quote) {
        if (content_to_quote != null) {
            string message_content = "<br/><br/>";
            string DATE_FORMAT = _("%a, %b %-e, %Y at %-l:%M %p");
            string when = new DateTime.from_unix_utc (message.date_received).format (DATE_FORMAT);
            string who = message.from;
            message_content += _("On %1$s, %2$s wrote:").printf (when, who);
            message_content += "<br/>";
            message_content += "<blockquote type=\"cite\">%s</blockquote>".printf (content_to_quote);
            web_view.set_body_content (message_content);
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
        actions.change_action_state (ACTION_BOLD, web_view.query_command_state ("bold") ? ACTION_BOLD : "");
        actions.change_action_state (ACTION_ITALIC, web_view.query_command_state ("italic") ? ACTION_ITALIC : "");
        actions.change_action_state (ACTION_UNDERLINE, web_view.query_command_state ("underline") ? ACTION_UNDERLINE : "");
        actions.change_action_state (ACTION_STRIKETHROUGH, web_view.query_command_state ("strikethrough") ? ACTION_STRIKETHROUGH : "");
    }

    private void on_discard () {
        discarded ();
    }
}
