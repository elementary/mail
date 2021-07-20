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

    private const string ACTION_ADD_ATTACHMENT= "add-attachment";
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
    public string? subject { get; set; }
    public string? to { get; construct; }
    public string? mailto_query { get; construct; }

    private bool discard_draft = false;

    private WebView web_view;
    private SimpleActionGroup actions;
    private Gtk.Entry to_val;
    private Gtk.Entry cc_val;
    private Gtk.Entry bcc_val;
    private Gtk.FlowBox attachment_box;
    private Gtk.Revealer cc_revealer;
    private Gtk.ToggleButton cc_button;
    private Granite.Widgets.OverlayBar message_url_overlay;
    private Gtk.ComboBoxText from_combo;
    private Gtk.Entry subject_val;

    public enum Type {
        REPLY,
        REPLY_ALL,
        FORWARD
    }

    public const ActionEntry[] ACTION_ENTRIES = {
        {ACTION_ADD_ATTACHMENT, on_add_attachment },
        {ACTION_BOLD, on_edit_action, "s", "''" },
        {ACTION_ITALIC, on_edit_action, "s", "''" },
        {ACTION_UNDERLINE, on_edit_action, "s", "''" },
        {ACTION_STRIKETHROUGH, on_edit_action, "s", "''" },
        {ACTION_INSERT_LINK, on_insert_link_clicked, },
        {ACTION_REMOVE_FORMAT, on_remove_format },
        {ACTION_DISCARD, on_discard },
        {ACTION_SEND, on_send }
    };

    public ComposerWidget.inline () {
        Object (can_change_sender: false, has_subject_field: true);
    }

    public ComposerWidget.with_subject () {
        Object (has_subject_field: true);
    }

    public ComposerWidget.with_headers (string? to, string? mailto_query) {
        Object (
            has_subject_field: true,
            to: to,
            mailto_query: mailto_query
        );
    }

    construct {
        actions = new SimpleActionGroup ();
        actions.add_action_entries (ACTION_ENTRIES, this);
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

        cc_button = new Gtk.ToggleButton.with_label (_("Cc"));

        var bcc_button = new Gtk.ToggleButton.with_label (_("Bcc"));

        var to_grid = new EntryGrid ();
        to_grid.add (to_val);
        to_grid.add (cc_button);
        to_grid.add (bcc_button);

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
        bind_property ("subject", subject_val, "text", GLib.BindingFlags.BIDIRECTIONAL);

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
            tooltip_markup = Granite.markup_accel_tooltip ({""}, _("Underline"))
        };

        var strikethrough = new Gtk.ToggleButton () {
            action_name = ACTION_PREFIX + ACTION_STRIKETHROUGH,
            action_target = ACTION_STRIKETHROUGH,
            image = new Gtk.Image.from_icon_name ("format-text-strikethrough-symbolic", Gtk.IconSize.MENU),
            tooltip_markup = Granite.markup_accel_tooltip ({""}, _("Strikethrough"))
        };

        var clear_format = new Gtk.Button.from_icon_name ("format-text-clear-formatting-symbolic", Gtk.IconSize.MENU) {
            action_name = ACTION_PREFIX + ACTION_REMOVE_FORMAT,
            tooltip_markup = Granite.markup_accel_tooltip ({""}, _("Remove formatting"))
        };

        var formatting_buttons = new Gtk.Grid ();
        formatting_buttons.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        formatting_buttons.add (bold);
        formatting_buttons.add (italic);
        formatting_buttons.add (underline);
        formatting_buttons.add (strikethrough);

        var link = new Gtk.Button.from_icon_name ("insert-link-symbolic", Gtk.IconSize.MENU) {
            action_name = ACTION_PREFIX + ACTION_INSERT_LINK,
            tooltip_markup = Granite.markup_accel_tooltip ({""}, _("Insert Link"))
        };

        var button_row = new Gtk.Grid () {
            column_spacing = 12,
            margin_start = 6,
            margin_bottom = 6
        };
        button_row.add (formatting_buttons);
        button_row.add (clear_format );
        button_row.add (link);

        web_view = new WebView ();
        try {
            var template = resources_lookup_data ("/io/elementary/mail/blank-message-template.html", ResourceLookupFlags.NONE);
            web_view.load_html ((string)template.get_data ());
        } catch (Error e) {
            warning ("Failed to load blank message template: %s", e.message);
        }

        web_view.selection_changed.connect (update_actions);
        web_view.mouse_target_changed.connect (on_mouse_target_changed);

        attachment_box = new Gtk.FlowBox () {
            homogeneous = true,
            selection_mode = Gtk.SelectionMode.NONE
        };
        attachment_box.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);

        var discard = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.MENU) {
            action_name = ACTION_PREFIX + ACTION_DISCARD,
            tooltip_text = _("Delete draft")
        };

        var attach = new Gtk.Button.from_icon_name ("mail-attachment-symbolic", Gtk.IconSize.MENU) {
            action_name = ACTION_PREFIX + ACTION_ADD_ATTACHMENT,
            tooltip_markup = Granite.markup_accel_tooltip ({""}, _("Attach file"))
        };

        var send = new Gtk.Button.from_icon_name ("mail-send-symbolic", Gtk.IconSize.MENU) {
            action_name = ACTION_PREFIX + ACTION_SEND,
            always_show_image = true,
            label = _("Send"),
            margin = 6,
            margin_end = 0,
            sensitive = false
        };
        send.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var action_bar = new Gtk.ActionBar () {
            // Workaround styling issue
            margin_top = 1
        };
        action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        action_bar.pack_start (discard);
        action_bar.pack_start (attach);
        action_bar.pack_end (send);

        var view_overlay = new Gtk.Overlay ();
        view_overlay.add (web_view);
        message_url_overlay = new Granite.Widgets.OverlayBar (view_overlay);
        message_url_overlay.no_show_all = true;

        orientation = Gtk.Orientation.VERTICAL;
        add (recipient_grid);
        add (button_row);
        add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        add (view_overlay);
        add (attachment_box);
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
            on_sanitize_recipient_entry (cc_val);
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
            on_sanitize_recipient_entry (bcc_val);
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
            on_sanitize_recipient_entry (to_val);
            has_recipients = to_val.text != "";
        });

        to_val.get_style_context ().changed.connect (() => {
            unowned Gtk.StyleContext to_grid_style_context = to_grid.get_style_context ();
            var state = to_grid_style_context.get_state ();
            if (to_val.has_focus) {
                state |= Gtk.StateFlags.FOCUSED;
            } else {
                state ^= Gtk.StateFlags.FOCUSED;
            }

            to_grid_style_context.set_state (state);
        });

        if (to != null) {
            to_val.text = to;
        }

        if (mailto_query != null) {
            var result = new Gee.HashMap<string, string> ();
            var params = mailto_query.split ("&");

            foreach (unowned string param in params) {
                var terms = param.split ("=");
                if (terms.length == 2) {
                    result[terms[0].down ()] = Soup.URI.decode (terms[1]);
                } else {
                    critical ("Invalid mailto URL");
                }
            }

            if (result["bcc"] != null) {
                bcc_button.clicked ();
                bcc_val.text = result["bcc"];
            }

            if (result["cc"] != null) {
                cc_button.clicked ();
                cc_val.text = result["cc"];
            }

            if (result["subject"] != null) {
                subject_val.text = result["subject"];
            }

            if (result["body"] != null) {
                var flags =
                    Camel.MimeFilterToHTMLFlags.CONVERT_ADDRESSES |
                    Camel.MimeFilterToHTMLFlags.CONVERT_NL |
                    Camel.MimeFilterToHTMLFlags.CONVERT_SPACES |
                    Camel.MimeFilterToHTMLFlags.CONVERT_URLS;

                web_view.set_body_content (Camel.text_to_html (result["body"], flags, 0));
            }
        }
    }

    private void on_sanitize_recipient_entry (Gtk.Entry entry) {
        if (entry.text == "") {
            return;
        }
        if (entry.text.contains ("\n") ) {
            entry.text = entry.text.replace ("\n", ", ");
        }
        if (entry.text.contains ("\r") ) {
            entry.text = entry.text.replace ("\r", ", ");
        }
    }

    private void on_add_attachment () {
        var filechooser = new Gtk.FileChooserNative (
            _("Choose a file"),
            (Gtk.Window) get_toplevel (),
            Gtk.FileChooserAction.OPEN,
            _("Attach"),
            _("Cancel")
        );

        if (filechooser.run () == Gtk.ResponseType.ACCEPT) {
            filechooser.hide ();
            foreach (unowned File file in filechooser.get_files ()) {
                var attachment = new Attachment (file);
                attachment.margin = 3;

                attachment_box.add (attachment);
            }
            attachment_box.show_all ();
        }
        filechooser.destroy ();
    }

    private void on_insert_link_clicked () {
        ask_insert_link.begin ();
    }

    private async void ask_insert_link () {
        var selected_text = yield web_view.get_selected_text ();
        var insert_link_dialog = new InsertLinkDialog (selected_text);
        insert_link_dialog.insert_link.connect ((url, title) => on_link_inserted (url, title, selected_text));
        insert_link_dialog.transient_for = (Gtk.Window) get_toplevel ();
        insert_link_dialog.run ();
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
            string date_format = _("%a, %b %-e, %Y at %-l:%M %p");
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

                string when = new DateTime.from_unix_utc (info.date_received).format (date_format);
                string who = Utils.escape_html_tags (message.get_from ().format ());
                message_content += _("On %1$s, %2$s wrote:").printf (when, who);
                message_content += "<br/>";
                message_content += "<blockquote type=\"cite\">%s</blockquote>".printf (content_to_quote);
            } else if (type == Type.FORWARD) {
                message_content += _("---------- Forwarded message ----------");
                message_content += "<br/><br/>";
                message_content += _("From: %s<br/>").printf (Utils.escape_html_tags (message.get_from ().format ()));
                message_content += _("Subject: %s<br/>").printf (Utils.escape_html_tags (info.subject));
                message_content += _("Date: %s<br/>").printf (new DateTime.from_unix_utc (info.date_received).format (date_format));
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
        web_view.query_command_state.begin ("bold", (obj, res) => {
            actions.change_action_state (ACTION_BOLD, web_view.query_command_state.end (res) ? ACTION_BOLD : "");
        });
        web_view.query_command_state.begin ("italic", (obj, res) => {
            actions.change_action_state (ACTION_ITALIC, web_view.query_command_state.end (res) ? ACTION_ITALIC : "");
        });
        web_view.query_command_state.begin ("underline", (obj, res) => {
            actions.change_action_state (ACTION_UNDERLINE, web_view.query_command_state.end (res) ? ACTION_UNDERLINE : "");
        });
        web_view.query_command_state.begin ("strikethrough", (obj, res) => {
            actions.change_action_state (ACTION_STRIKETHROUGH, web_view.query_command_state.end (res) ? ACTION_STRIKETHROUGH : "");
        });
    }

    private void on_discard () {
        var discard_dialog = new Granite.MessageDialog (
            _("Permanently delete this draft?"),
            _("You cannot undo this action, nor recover your draft once it has been deleted."),
            new ThemedIcon ("mail-drafts"),
            Gtk.ButtonsType.NONE
        ) {
            badge_icon = new ThemedIcon ("edit-delete"),
            transient_for = get_toplevel () as Gtk.Window
        };

        discard_dialog.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        var discard_anyway = discard_dialog.add_button (_("Delete Draft"), Gtk.ResponseType.ACCEPT);
        discard_anyway.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        if (discard_dialog.run () == Gtk.ResponseType.ACCEPT) {
            discard_draft = true;
            discarded ();
        }

        discard_dialog.destroy ();
    }

    private void on_send () {
        send_message.begin ();
    }

    private async void send_message () {
        if (subject_val.text == "") {
            var no_subject_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Send without subject?"),
                _("This message has an empty subject field. The recipient may be unable to infer its scope or importance."),
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
        var body_html = yield web_view.get_body_html ();
        var message = build_message (body_html);
        var sender = build_sender (message, from_combo.get_active_text ());
        var recipients = build_recipients (message, to_val.text, cc_val.text, bcc_val.text);

        try {
            var sent_message_saved = yield session.send_email (message, sender, recipients);

            if (!sent_message_saved) {
                var warning_dialog = new Granite.MessageDialog (
                    _("Sent message was not saved"),
                    _("The message was sent, however a copy was not saved to the Sent message folder."),
                    new ThemedIcon ("mail-send"),
                    Gtk.ButtonsType.CLOSE
                ) {
                    badge_icon = new ThemedIcon ("dialog-warning")
                };
                warning_dialog.run ();
                warning_dialog.destroy ();
            }

            discard_draft = true;
            sent ();

        } catch (Error e) {
            var error_dialog = new Granite.MessageDialog (
                _("Unable to send message"),
                _("There was an unexpected error while sending your message."),
                new ThemedIcon ("mail-send"),
                Gtk.ButtonsType.CLOSE
            ) {
                badge_icon = new ThemedIcon ("dialog-error")
            };
            error_dialog.show_error_details (e.message);
            error_dialog.run ();
            error_dialog.destroy ();
        }
    }

    private Camel.InternetAddress build_sender (Camel.MimeMessage message, string from) {
        var sender = new Camel.InternetAddress ();
        sender.unformat (from);
        message.set_from (sender);

        return sender;
    }

    private Camel.InternetAddress build_recipients (Camel.MimeMessage message, string to, string cc, string bcc) {
        var to_addresses = new Camel.InternetAddress ();
        to_addresses.unformat (to);
        message.set_recipients (Camel.RECIPIENT_TYPE_TO, to_addresses);

        var cc_addresses = new Camel.InternetAddress ();
        cc_addresses.unformat (cc);
        message.set_recipients (Camel.RECIPIENT_TYPE_CC, cc_addresses);

        var bcc_addresses = new Camel.InternetAddress ();
        bcc_addresses.unformat (bcc);
        message.set_recipients (Camel.RECIPIENT_TYPE_BCC, bcc_addresses);

        var recipients = new Camel.InternetAddress ();
        recipients.cat (to_addresses);
        recipients.cat (cc_addresses);
        recipients.cat (bcc_addresses);

        return recipients;
    }

    private Camel.MimeMessage build_message (string body_html) {
        var stream_mem = new Camel.StreamMem.with_buffer (body_html.data);
        var stream_filter = new Camel.StreamFilter (stream_mem);

        var html = new Camel.DataWrapper ();
        try {
            html.construct_from_stream_sync (stream_filter);
            html.set_mime_type ("text/html; charset=utf-8");
        } catch (Error e) {
            warning ("Error constructing html from stream: %s", e.message);
        }

        var part = new Camel.MimePart ();
        part.content = html;
        part.set_encoding (Camel.TransferEncoding.ENCODING_QUOTEDPRINTABLE);

        var body = new Camel.Multipart ();
        body.set_mime_type ("multipart/alternative");
        body.set_boundary (null);
        body.add_part (part);

        if (attachment_box.get_children ().length () > 0) {
            foreach (unowned Gtk.Widget attachment in attachment_box.get_children ()) {
                if (!(attachment is Attachment)) {
                    continue;
                }

                unowned var attachment_obj = (Attachment)attachment;

                body.add_part (attachment_obj.get_mime_part ());
            }
        }

        var message = new Camel.MimeMessage ();
        message.set_subject (subject_val.text);
        message.set_date (Camel.MESSAGE_DATE_CURRENT, 0);
        message.content = body;

        return message;
    }

    private void load_from_combobox () {
        unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();
        foreach (var address in session.get_own_addresses ()) {
            from_combo.append_text (address);
        }

        from_combo.active = 0;
    }

    private class Attachment : Gtk.FlowBoxChild {
        public GLib.FileInfo? info { private get; construct; }
        public GLib.File file { get; construct; }

        public Attachment (GLib.File file) {
            Object (
                file: file
            );
        }

        construct {
            const string QUERY_STRING =
                GLib.FileAttribute.STANDARD_CONTENT_TYPE + "," +
                GLib.FileAttribute.STANDARD_DISPLAY_NAME + "," +
                GLib.FileAttribute.STANDARD_ICON + "," +
                GLib.FileAttribute.STANDARD_SIZE;

            try {
                info = file.query_info (QUERY_STRING, GLib.FileQueryInfoFlags.NONE);
            } catch (Error e) {
                warning ("Error querying attachment file attributes: %s", e.message);
            }

            var image = new Gtk.Image () {
                gicon = info.get_icon (),
                pixel_size = 24
            };

            var name_label = new Gtk.Label (info.get_display_name ()) {
                hexpand = true,
                xalign = 0
            };

            var size_label = new Gtk.Label ("(%s)".printf (GLib.format_size (info.get_size ())));
            size_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

            var remove_button = new Gtk.Button.from_icon_name ("process-stop-symbolic", Gtk.IconSize.SMALL_TOOLBAR);

            unowned Gtk.StyleContext remove_button_context = remove_button.get_style_context ();
            remove_button_context.add_class (Gtk.STYLE_CLASS_FLAT);
            remove_button_context.add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

            var grid = new Gtk.Grid () {
                column_spacing = 3,
                margin = 3
            };
            grid.add (image);
            grid.add (name_label);
            grid.add (size_label);
            grid.add (remove_button);

            add (grid);

            remove_button.clicked.connect (() => {
                destroy ();
            });
        }

        public Camel.MimePart? get_mime_part () {
            if (info == null) {
                return null;
            }

            unowned string? content_type = info.get_content_type ();
            var mime_type = GLib.ContentType.get_mime_type (content_type);

            var wrapper = new Camel.DataWrapper ();
            try {
                wrapper.construct_from_input_stream_sync (file.read ());
            } catch (Error e) {
                warning ("Error constructing wrapper for attachment: %s", e.message);
                return null;
            }

            wrapper.set_mime_type (mime_type);

            var mimepart = new Camel.MimePart ();
            mimepart.set_disposition ("attachment");
            mimepart.set_filename (info.get_display_name ());
            ((Camel.Medium)mimepart).set_content (wrapper);

            if (mimepart.get_content_type ().is ("text", "*")) {
                // Run text files through a stream filter to get the best transfer encoding
                var stream = new Camel.StreamNull ();
                var filtered_stream = new Camel.StreamFilter (stream);
                var filter = new Camel.MimeFilterBestenc (Camel.BestencRequired.GET_ENCODING);
                filtered_stream.add (filter);

                try {
                    wrapper.decode_to_stream_sync (filtered_stream);

                    var encoding = filter.get_best_encoding (Camel.BestencEncoding.@8BIT);
                    mimepart.set_encoding (encoding);
                } catch (Error e) {
                    warning ("Unable to determine best encoding for attachment: %s", e.message);
                }
            } else {
                // Otherwise use Base64
                mimepart.set_encoding (Camel.TransferEncoding.ENCODING_BASE64);
            }

            return mimepart;
        }
    }

    private class EntryGrid : Gtk.Grid {
        static construct {
            set_css_name (Gtk.STYLE_CLASS_ENTRY);
        }
    }

    public override void destroy () {
        if (discard_draft) {
            base.destroy ();
            return;
        }

        web_view.get_body_html.begin ((obj, res) => {
            var body_html = web_view.get_body_html.end (res);

            if (body_html == null) {
                base.destroy ();

            } else {
                unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();

                var message = build_message (body_html);
                var sender = build_sender (message, from_combo.get_active_text ());
                var recipients = build_recipients (message, to_val.text, cc_val.text, bcc_val.text);

                session.save_draft.begin (
                    message,
                    sender,
                    recipients,
                    (obj, res) => {
                        try {
                            session.save_draft.end (res);
                            base.destroy ();

                        } catch (Error e) {
                            unowned Mail.MainWindow? main_window = null;
                            var windows = Gtk.Window.list_toplevels ();
                            foreach (unowned var window in windows) {
                                if (window is Mail.MainWindow) {
                                    main_window = (Mail.MainWindow) window;
                                    break;
                                }
                            }

                            if (main_window != null) {
                                new ComposerWindow.for_widget (main_window, this).show_all ();
                            } else {
                                warning ("Unable to re-show composer. Draft will be lost.");
                            }

                            var error_dialog = new Granite.MessageDialog (
                                _("Unable to save draft"),
                                _("There was an unexpected error while saving your draft."),
                                new ThemedIcon ("mail-drafts"),
                                Gtk.ButtonsType.CLOSE
                            ) {
                                badge_icon = new ThemedIcon ("dialog-error")
                            };
                            error_dialog.show_error_details (e.message);
                            error_dialog.run ();
                            error_dialog.destroy ();
                        }
                });
            }
        });
    }
}
