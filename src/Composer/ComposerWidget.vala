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
    public signal void sent ();

    private const string ACTION_GROUP_PREFIX = "composer";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    private const string ACTION_BOLD = "bold";
    private const string ACTION_ITALIC = "italic";
    private const string ACTION_UNDERLINE = "underline";
    private const string ACTION_STRIKETHROUGH = "strikethrough";
    private const string ACTION_INSERT_LINK = "insert_link";
    private const string ACTION_REMOVE_FORMAT = "remove_formatting";
    private const string ACTION_DISCARD = "discard";
    private const string ACTION_SEND = "send";

    public bool has_recipients { get; set; }
    public bool has_subject_field { get; construct; default = false; }
    public bool can_change_sender { get; construct; default = true; }

    private WebView web_view;
    private SimpleActionGroup actions;
    private Gtk.Entry to_val;
    private Gtk.Entry cc_val;
    private Gtk.Entry bcc_val;
    private Gtk.Revealer cc_revealer;
    private Granite.Widgets.OverlayBar message_url_overlay;
    private Gtk.ComboBoxText from_combo;
    private Gtk.Entry subject_val;

    public enum Type {
        REPLY,
        REPLY_ALL,
        FORWARD
    }

    public const ActionEntry[] action_entries = {
        {ACTION_BOLD,           on_edit_action,    "s",    "''"     },
        {ACTION_ITALIC,         on_edit_action,    "s",    "''"     },
        {ACTION_UNDERLINE,      on_edit_action,    "s",    "''"     },
        {ACTION_STRIKETHROUGH,  on_edit_action,    "s",    "''"     },
        {ACTION_INSERT_LINK,    on_insert_link_clicked,             },
        {ACTION_REMOVE_FORMAT,  on_remove_format                    },
        {ACTION_DISCARD,        on_discard                          },
        {ACTION_SEND,           on_send                             }
    };

    public ComposerWidget () {
        
    }

    public ComposerWidget.inline () {
        Object (can_change_sender: false);
    }

    public ComposerWidget.with_subject () {
        Object (has_subject_field: true);
    }

    construct {
        actions = new SimpleActionGroup ();
        actions.add_action_entries (action_entries, this);
        insert_action_group (ACTION_GROUP_PREFIX, actions);

        var from_label = new Gtk.Label (_("From:"));
        from_label.xalign = 1;
        from_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        from_combo = new Gtk.ComboBoxText ();
        from_combo.hexpand = true;

        var from_grid = new Gtk.Grid ();
        from_grid.column_spacing = 6;
        from_grid.margin_bottom = 6;
        from_grid.add (from_label);
        from_grid.add (from_combo);

        var from_revealer = new Gtk.Revealer ();
        from_revealer.add (from_grid);

        var to_label = new Gtk.Label (_("To:"));
        to_label.xalign = 1;
        to_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var subject_label = new Gtk.Label (_("Subject:"));
        subject_label.xalign = 1;
        subject_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        to_val = new Gtk.Entry ();
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

        cc_val = new Gtk.Entry ();
        cc_val.hexpand = true;

        var cc_grid = new Gtk.Grid ();
        cc_grid.column_spacing = 6;
        cc_grid.margin_top = 6;
        cc_grid.add (cc_label);
        cc_grid.add (cc_val);

        cc_revealer = new Gtk.Revealer ();
        cc_revealer.add (cc_grid);

        var bcc_label = new Gtk.Label (_("Bcc:"));
        bcc_label.xalign = 1;
        bcc_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        bcc_val = new Gtk.Entry ();
        bcc_val.hexpand = true;

        var bcc_grid = new Gtk.Grid ();
        bcc_grid.column_spacing = 6;
        bcc_grid.margin_top = 6;
        bcc_grid.add (bcc_label);
        bcc_grid.add (bcc_val);

        var bcc_revealer = new Gtk.Revealer ();
        bcc_revealer.add (bcc_grid);

        subject_val = new Gtk.Entry ();
        subject_val.margin_top = 6;

        var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
        size_group.add_widget (from_label);
        size_group.add_widget (to_label);
        size_group.add_widget (cc_label);
        size_group.add_widget (bcc_label);
        size_group.add_widget (subject_label);

        var recipient_grid = new Gtk.Grid ();
        recipient_grid.margin = 6;
        recipient_grid.column_spacing = 6;
        recipient_grid.attach (from_revealer, 0, 0, 2, 1);
        recipient_grid.attach (to_label, 0, 1);
        recipient_grid.attach (to_grid, 1, 1);
        recipient_grid.attach (cc_revealer, 0, 2, 2, 1);
        recipient_grid.attach (bcc_revealer, 0, 3, 2, 1);
        if (has_subject_field) {
            recipient_grid.attach (subject_label, 0, 4);
            recipient_grid.attach (subject_val, 1, 4);
        }

        var bold = new Gtk.ToggleButton ();
        bold.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>B"}, _("Bold"));
        bold.image = new Gtk.Image.from_icon_name ("format-text-bold-symbolic", Gtk.IconSize.MENU);
        bold.action_name = ACTION_PREFIX + ACTION_BOLD;
        bold.action_target = ACTION_BOLD;

        var italic = new Gtk.ToggleButton ();
        italic.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>I"}, _("Italic"));
        italic.image = new Gtk.Image.from_icon_name ("format-text-italic-symbolic", Gtk.IconSize.MENU);
        italic.action_name = ACTION_PREFIX + ACTION_ITALIC;
        italic.action_target = ACTION_ITALIC;

        var underline = new Gtk.ToggleButton ();
        underline.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>U"}, _("Underline"));
        underline.image = new Gtk.Image.from_icon_name ("format-text-underline-symbolic", Gtk.IconSize.MENU);
        underline.action_name = ACTION_PREFIX + ACTION_UNDERLINE;
        underline.action_target = ACTION_UNDERLINE;

        var strikethrough = new Gtk.ToggleButton ();
        strikethrough.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>percent"}, _("Strikethrough"));
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
        indent_more.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>bracketright"}, _("Quote text"));

        var indent_less = new Gtk.Button.from_icon_name ("format-indent-less-symbolic", Gtk.IconSize.MENU);
        indent_less.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>bracketleft"}, _("Unquote text"));

        var indent_buttons = new Gtk.Grid ();
        indent_buttons.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        indent_buttons.add (indent_more);
        indent_buttons.add (indent_less);

        var link = new Gtk.Button.from_icon_name ("insert-link-symbolic", Gtk.IconSize.MENU);
        link.action_name = ACTION_PREFIX + ACTION_INSERT_LINK;
        link.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>K"}, _("Insert Link"));

        var image = new Gtk.Button.from_icon_name ("insert-image-symbolic", Gtk.IconSize.MENU);
        image.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>G"}, _("Insert Image"));

        var clear_format = new Gtk.Button.from_icon_name ("format-text-clear-formatting-symbolic", Gtk.IconSize.MENU);
        clear_format.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>space"}, _("Remove formatting"));
        clear_format.action_name = ACTION_PREFIX + ACTION_REMOVE_FORMAT;

        var button_row = new Gtk.Grid ();
        button_row.column_spacing = 6;
        button_row.margin_start = 6;
        button_row.margin_bottom = 6;
        button_row.add (formatting_buttons);
        button_row.add (indent_buttons);
        button_row.add (link);
        button_row.add (image);
        button_row.add (clear_format);

        web_view = new WebView ();
        try {
            var template = resources_lookup_data ("/io/elementary/mail/blank-message-template.html", ResourceLookupFlags.NONE);
            web_view.load_html ((string)template.get_data ());
        } catch (Error e) {
            warning ("Failed to load blank message template: %s", e.message);
        }

        web_view.selection_changed.connect (update_actions);
        web_view.mouse_target_changed.connect (on_mouse_target_changed);

        var action_bar = new Gtk.ActionBar ();

        var discard = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.MENU);
        discard.margin_start = 6;
        discard.tooltip_text = _("Delete draft");
        discard.action_name = ACTION_PREFIX + ACTION_DISCARD;

        var attach = new Gtk.Button.from_icon_name ("mail-attachment-symbolic", Gtk.IconSize.MENU);
        attach.tooltip_text = _("Attach file");

        var send = new Gtk.Button.from_icon_name ("mail-send-symbolic", Gtk.IconSize.MENU);
        send.margin = 6;
        send.sensitive = false;
        send.always_show_image = true;
        send.label = _("Send");
        send.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>ISO_Enter"});
        send.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        send.action_name = ACTION_PREFIX + ACTION_SEND;

        action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);

        action_bar.pack_start (discard);
        action_bar.pack_start (attach);
        action_bar.pack_end (send);

        var view_overlay = new Gtk.Overlay();
        view_overlay.add (web_view);
        message_url_overlay = new Granite.Widgets.OverlayBar (view_overlay);
        message_url_overlay.no_show_all = true;

        orientation = Gtk.Orientation.VERTICAL;
        add (recipient_grid);
        add (button_row);
        add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        add (view_overlay);
        add (action_bar);

        var contact_manager = ContactManager.get_default ();
        contact_manager.setup_entry (to_val);
        contact_manager.setup_entry (cc_val);
        contact_manager.setup_entry (bcc_val);

        load_from_combobox ();
        if (from_combo.model.iter_n_children (null) > 1) {
            from_revealer.reveal_child = true && can_change_sender;
        }

        bind_property ("has-recipients", send, "sensitive");

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

        from_combo.changed.connect (() => {
            // from_revealer.reveal_child = 
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

    private void on_insert_link_clicked () {
        var insert_link_dialog = new InsertLinkDialog (web_view.get_selected_text ());
        insert_link_dialog.insert_link.connect (on_link_inserted);
        insert_link_dialog.transient_for = (Gtk.Window) get_toplevel ();
        insert_link_dialog.run ();
    }

    private void on_link_inserted (string url, string title) {
        var selected_text = web_view.get_selected_text ();
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

    private void on_mouse_target_changed (WebKit.WebView web_view, WebKit.HitTestResult hit_test, uint mods) {
        if (hit_test.context_is_link ()) {
            var url = hit_test.get_link_uri ();
            var hover_url = url != null ? Soup.URI.decode (url) : null;

            if (hover_url == null) {
                message_url_overlay.hide ();
            } else {
                message_url_overlay.label = hover_url;
                message_url_overlay.no_show_all = false;
                message_url_overlay.show_all ();
            }
        } else {
            message_url_overlay.hide ();
        }
    }

    public void quote_content (Type type, Camel.MessageInfo info, Camel.MimeMessage message, string? content_to_quote) {
        if (content_to_quote != null) {
            string message_content = "<br/><br/>";
            string DATE_FORMAT = _("%a, %b %-e, %Y at %-l:%M %p");
            if (type == Type.REPLY || type == Type.REPLY_ALL) {
                var reply_to = message.get_reply_to ();
                if (reply_to != null) {
                    to_val.text = reply_to.format ();
                } else {
                    to_val.text = message.get_from ().format ();
                }

                if (type == Type.REPLY_ALL) {
                    var to_addresses = Utils.get_reply_addresses (info.to, (address) => { return true; });
                    to_val.text += ", %s".printf (to_addresses);

                    if (info.cc != null) {
                        cc_val.text = Utils.get_reply_addresses (info.cc, (address) => {
                            if (to_val.text.contains (address)) {
                                return false;
                            }

                            return true;
                        });

                        if (cc_val.text.length > 0) {
                            cc_revealer.reveal_child = true;
                        }
                    }
                }

                string when = new DateTime.from_unix_utc (info.date_received).format (DATE_FORMAT);
                string who = Utils.escape_html_tags (message.get_from ().format ());
                message_content += _("On %1$s, %2$s wrote:").printf (when, who);
                message_content += "<br/>";
                message_content += "<blockquote type=\"cite\">%s</blockquote>".printf (content_to_quote);
            } else if (type == Type.FORWARD) {
                message_content += _("---------- Forwarded message ----------");
                message_content += "<br/><br/>";
                message_content += _("From: %s<br/>").printf (Utils.escape_html_tags (message.get_from ().format ()));
                message_content += _("Subject: %s<br/>").printf (Utils.escape_html_tags (info.subject));
                message_content += _("Date: %s<br/>").printf (new DateTime.from_unix_utc (info.date_received).format (DATE_FORMAT));
                message_content += _("To: %s<br/>").printf (Utils.escape_html_tags (info.to));
                if (info.cc != null && info.cc != "") {
                    message_content += _("Cc: %s<br/>").printf (Utils.escape_html_tags (info.cc));
                }
                message_content += "<br/><br/>";
                message_content += content_to_quote;
            }

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

    private void on_send () {
        if (subject_val.text == "") {
            var no_subject_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Send Message With an Empty Subject?"),
                _("This message has an empty subject field. The recipient may not be able to infer the scope or importance of the message."),
                "mail-send",
                Gtk.ButtonsType.NONE
            );
            no_subject_dialog.transient_for = get_toplevel () as Gtk.Window;

            no_subject_dialog.add_button (_("Don't Send"), Gtk.ResponseType.CANCEL);

            var send_anyway = no_subject_dialog.add_button (_("Send Anyway"), Gtk.ResponseType.ACCEPT);
            send_anyway.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

            if (no_subject_dialog.run () == Gtk.ResponseType.CANCEL) {
                no_subject_dialog.destroy ();
                return;
            }
            no_subject_dialog.destroy ();
        }

        unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();

        var from = new Camel.InternetAddress ();
        from.unformat (from_combo.get_active_text ());

        var to_addresses = new Camel.InternetAddress ();
        to_addresses.unformat (to_val.text);

        var cc_addresses = new Camel.InternetAddress ();
        cc_addresses.unformat (cc_val.text);

        var bcc_addresses = new Camel.InternetAddress ();
        bcc_addresses.unformat (bcc_val.text);

        var recipients = new Camel.InternetAddress ();
        recipients.cat (to_addresses);
        recipients.cat (cc_addresses);
        recipients.cat (bcc_addresses);

        var body_html = web_view.get_body_html ();
        var message = new Camel.MimeMessage ();
        message.set_from (from);
        message.set_recipients (Camel.RECIPIENT_TYPE_TO, to_addresses);
        message.set_recipients (Camel.RECIPIENT_TYPE_CC, cc_addresses);
        message.set_recipients (Camel.RECIPIENT_TYPE_BCC, bcc_addresses);
        message.set_subject (subject_val.text);
        message.set_date (Camel.MESSAGE_DATE_CURRENT, 0);

        var stream_mem = new Camel.StreamMem.with_buffer (body_html.data);
        var stream_filter = new Camel.StreamFilter (stream_mem);

        var html = new Camel.DataWrapper ();
        html.construct_from_stream_sync (stream_filter);
        html.set_mime_type ("text/html; charset=utf-8");

        var body = new Camel.Multipart ();
        body.set_mime_type ("multipart/alternative");
        body.set_boundary (null);

        var part = new Camel.MimePart ();
        part.content = html;
        part.set_encoding (Camel.TransferEncoding.ENCODING_QUOTEDPRINTABLE);
        body.add_part (part);
        message.content = body;

        session.send_email.begin (message, from, recipients);
        sent ();
    }

    private void load_from_combobox () {
        unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();
        foreach (var address in session.get_own_addresses ()) {
            from_combo.append_text (address);
        }

        from_combo.active = 0;
    }
}
