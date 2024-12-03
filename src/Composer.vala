/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017-2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

public class Mail.Composer : Hdy.ApplicationWindow {
    public signal void finished ();

    private const string ACTION_GROUP_PREFIX = "win";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    private const string ACTION_ADD_ATTACHMENT= "add-attachment";
    private const string ACTION_INSERT_IMAGE = "insert-image";
    private const string ACTION_INSERT_SIGNATURE = "insert-signature";
    private const string ACTION_DISCARD = "discard";
    private const string ACTION_SEND = "send";

    public bool has_recipients { get; set; }
    public string? to { get; construct; }
    public string? mailto_query { get; construct; }

    private bool discard_draft = false;
    private Camel.MessageInfo? ancestor_message_info = null;

    private WebView web_view;
    private Gtk.Entry to_val;
    private Gtk.Entry cc_val;
    private Gtk.Entry bcc_val;
    private Gtk.FlowBox attachment_box;
    private Gtk.Revealer cc_revealer;
    private Gtk.Revealer bcc_revealer;
    private Gtk.ToggleButton cc_button;
    private Granite.Widgets.OverlayBar message_url_overlay;
    private Gtk.ComboBoxText from_combo;
    private Gtk.Entry subject_val;

    public enum Type {
        REPLY,
        REPLY_ALL,
        FORWARD,
        DRAFT
    }

    private const ActionEntry[] ACTION_ENTRIES = {
        {ACTION_ADD_ATTACHMENT, on_add_attachment },
        {ACTION_INSERT_IMAGE, on_insert_image, },
        {ACTION_INSERT_SIGNATURE, on_insert_signature, "s" },
        {ACTION_DISCARD, on_discard },
        {ACTION_SEND, on_send }
    };

    public Composer (string? to = null, string? mailto_query = null) {
        Object (
            to: to,
            mailto_query: mailto_query
        );
    }

    public Composer.with_quote (Composer.Type type, Camel.MessageInfo info, Camel.MimeMessage message, string? content) {
        Object (has_recipients: true);
        quote_content (type, info, message, content);
    }

    construct {
        add_action_entries (ACTION_ENTRIES, this);

        application = (Gtk.Application) GLib.Application.get_default ();
        // Alt+I from Outlook, Shift+Ctrl+A from Apple Mail
        application.set_accels_for_action (ACTION_PREFIX + ACTION_ADD_ATTACHMENT, {"<Alt>I", "<Shift><Control>A"});
        application.set_accels_for_action (ACTION_PREFIX + ACTION_SEND, {"<Control>Return"});

        foreach (unowned var window in application.get_windows ()) {
            if (window is MainWindow) {
                transient_for = window;
                break;
            }
        }

        var headerbar = new Hdy.HeaderBar () {
            has_subtitle = false,
            show_close_button = true
        };
        headerbar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        headerbar.get_style_context ().add_class ("default-decoration");

        var from_label = new Gtk.Label (_("From:")) {
            xalign = 1
        };
        from_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        from_combo = new Gtk.ComboBoxText () {
            hexpand = true
        };

        var from_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_bottom = 6
        };
        from_box.add (from_label);
        from_box.add (from_combo);

        var from_revealer = new Gtk.Revealer () {
            child = from_box
        };

        var to_label = new Gtk.Label (_("To:")) {
            xalign = 1
        };
        to_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var subject_label = new Gtk.Label (_("Subject:")) {
            xalign = 1
        };
        subject_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        to_val = new Gtk.Entry () {
            hexpand = true
        };

        cc_button = new Gtk.ToggleButton.with_label (_("Cc"));

        var bcc_button = new Gtk.ToggleButton.with_label (_("Bcc"));

        var to_grid = new EntryGrid ();
        to_grid.add (to_val);
        to_grid.add (cc_button);
        to_grid.add (bcc_button);

        var cc_label = new Gtk.Label (_("Cc:")) {
            xalign = 1
        };
        cc_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        cc_val = new Gtk.Entry () {
            hexpand = true
        };

        var cc_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_top = 6
        };
        cc_box.add (cc_label);
        cc_box.add (cc_val);

        cc_revealer = new Gtk.Revealer ();
        cc_revealer.add (cc_box);

        var bcc_label = new Gtk.Label (_("Bcc:")) {
            xalign = 1
        };
        bcc_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        bcc_val = new Gtk.Entry () {
            hexpand = true
        };

        var bcc_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_top = 6
        };
        bcc_box.add (bcc_label);
        bcc_box.add (bcc_val);

        bcc_revealer = new Gtk.Revealer ();
        bcc_revealer.add (bcc_box);

        subject_val = new Gtk.Entry () {
            margin_top = 6
        };

        subject_val.changed.connect (() => {
            title = subject_val.text;
        });

        var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
        size_group.add_widget (from_label);
        size_group.add_widget (to_label);
        size_group.add_widget (cc_label);
        size_group.add_widget (bcc_label);
        size_group.add_widget (subject_label);

        var recipient_grid = new Gtk.Grid () {
            column_spacing = 6,
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        recipient_grid.attach (from_revealer, 0, 0, 2);
        recipient_grid.attach (to_label, 0, 1);
        recipient_grid.attach (to_grid, 1, 1);
        recipient_grid.attach (cc_revealer, 0, 2, 2);
        recipient_grid.attach (bcc_revealer, 0, 3, 2);
        recipient_grid.attach (subject_label, 0, 4);
        recipient_grid.attach (subject_val, 1, 4);

        var image = new Gtk.Button.from_icon_name ("insert-image-symbolic", Gtk.IconSize.MENU) {
            action_name = ACTION_PREFIX + ACTION_INSERT_IMAGE,
            tooltip_text = _("Insert Image")
        };

        web_view = new WebView ();
        try {
            var template = resources_lookup_data ("/io/elementary/mail/blank-message-template.html", ResourceLookupFlags.NONE);
            web_view.load_html ((string)template.get_data ());
        } catch (Error e) {
            warning ("Failed to load blank message template: %s", e.message);
        }

        web_view.mouse_target_changed.connect (on_mouse_target_changed);

        var editor_toolbar = new EditorToolbar (web_view);
        editor_toolbar.add (image);

        attachment_box = new Gtk.FlowBox () {
            homogeneous = true,
            selection_mode = Gtk.SelectionMode.NONE
        };
        attachment_box.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);

        var discard = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.MENU) {
            action_name = ACTION_PREFIX + ACTION_DISCARD,
            tooltip_markup = Granite.markup_accel_tooltip (
                application.get_accels_for_action (ACTION_PREFIX + ACTION_DISCARD),
                _("Delete draft")
            )
        };

        var attach = new Gtk.Button.from_icon_name ("mail-attachment-symbolic", Gtk.IconSize.MENU) {
            action_name = ACTION_PREFIX + ACTION_ADD_ATTACHMENT,
            tooltip_markup = Granite.markup_accel_tooltip (
                application.get_accels_for_action (ACTION_PREFIX + ACTION_ADD_ATTACHMENT),
                _("Attach file")
            )
        };

        var signature_menu = new Menu ();

        var signature_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("document-edit-symbolic", Gtk.IconSize.MENU),
            menu_model = signature_menu,
            use_popover = false,
            direction = UP,
            tooltip_text = _("Insert Signature…")
        };

        var send = new Gtk.Button.from_icon_name ("mail-send-symbolic", Gtk.IconSize.MENU) {
            action_name = ACTION_PREFIX + ACTION_SEND,
            always_show_image = true,
            label = _("Send"),
            margin_top = 6,
            margin_end = 0,
            margin_bottom = 6,
            margin_start = 6,
            sensitive = false,
            tooltip_markup = Granite.markup_accel_tooltip (
                application.get_accels_for_action (ACTION_PREFIX + ACTION_SEND)
            )
        };
        send.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var action_bar = new Gtk.ActionBar () {
            // Workaround styling issue
            margin_top = 1
        };
        action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        action_bar.pack_start (discard);
        action_bar.pack_start (attach);
        action_bar.pack_start (signature_button);
        action_bar.pack_end (send);

        var view_overlay = new Gtk.Overlay ();
        view_overlay.add (web_view);
        message_url_overlay = new Granite.Widgets.OverlayBar (view_overlay);
        message_url_overlay.no_show_all = true;

        var main_box = new Gtk.Box (VERTICAL, 0);
        main_box.add (headerbar);
        main_box.add (recipient_grid);
        main_box.add (editor_toolbar);
        main_box.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        main_box.add (view_overlay);
        main_box.add (attachment_box);
        main_box.add (action_bar);

        default_height = 500;
        default_width = 680;
        title = _("New Message");
        add (main_box);
        show_all ();

        delete_event.connect (() => {
            save_draft.begin ((obj, res) => {
                if (!save_draft.end (res)) {
                    finished ();
                    destroy ();
                };
            });
            return true;
        });

        var contact_manager = ContactManager.get_default ();
        contact_manager.setup_entry (to_val);
        contact_manager.setup_entry (cc_val);
        contact_manager.setup_entry (bcc_val);

        from_combo.changed.connect (() => {
            set_default_signature_for_sender ();
        });

        load_from_combobox ();
        from_revealer.reveal_child = from_combo.model.iter_n_children (null) > 1;

        bind_property ("has-recipients", send, "sensitive");
        bind_property ("title", headerbar, "title");

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

        unowned var session = Mail.Backend.Session.get_default ();
        session.signature_changed.connect (() => populate_signature_menu (signature_menu));
        populate_signature_menu (signature_menu);

        if (mailto_query != null) {
            var result = new Gee.HashMultiMap<string, string> ();
            var params = mailto_query.split ("&");

            foreach (unowned string param in params) {
                var terms = param.split ("=");
                if (terms.length == 2) {
                    result[terms[0].down ()] = (GLib.Uri.unescape_string (terms[1]));
                } else {
                    critical ("Invalid mailto URL");
                }
            }

            if ("bcc" in result) {
                bcc_button.clicked ();
                bcc_val.text = result["bcc"].to_array ()[0];
            }

            if ("cc" in result) {
                cc_button.clicked ();
                cc_val.text = result["cc"].to_array ()[0];
            }

            if ("subject" in result) {
                subject_val.text = result["subject"].to_array ()[0];
            }

            if ("body" in result) {
                var flags =
                    Camel.MimeFilterToHTMLFlags.CONVERT_ADDRESSES |
                    Camel.MimeFilterToHTMLFlags.CONVERT_NL |
                    Camel.MimeFilterToHTMLFlags.CONVERT_SPACES |
                    Camel.MimeFilterToHTMLFlags.CONVERT_URLS;

                web_view.set_content_of_element (
                    "#elementary-message-body",
                    Camel.text_to_html (result["body"].to_array ()[0], flags, 0)
                );
            }

            if ("attachment" in result) {
                foreach (var path in result["attachment"]) {
                    var file = path.has_prefix ("file://") ? File.new_for_uri (path) : File.new_for_path (path);

                    attachment_box.add (new Attachment (file, Attachment.DISPOSITION_ATTACHMENT));
                }
                attachment_box.show_all ();
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
                attachment_box.add (new Attachment (file, Attachment.DISPOSITION_ATTACHMENT));
            }
            attachment_box.show_all ();
        }

        filechooser.destroy ();
    }

    private void on_insert_image () {
        var image_filter = new Gtk.FileFilter ();
        image_filter.set_filter_name (_("Images"));
        image_filter.add_mime_type ("image/*");

        var filechooser = new Gtk.FileChooserNative (
            _("Choose an image"),
            (Gtk.Window) get_toplevel (),
            Gtk.FileChooserAction.OPEN,
            _("Insert"),
            _("Cancel")
        ) {
            filter = image_filter,
            select_multiple = false
        };

        filechooser.response.connect ((response) => {
            if (response == Gtk.ResponseType.ACCEPT) {
                var file = filechooser.get_file ();

                try {
                    var inpustream = file.read ();

                    var attachment = new Attachment (file, Attachment.DISPOSITION_INLINE);
                    attachment_box.add (attachment);

                    web_view.add_internal_resource (attachment.uri, inpustream);
                    web_view.execute_editor_command ("insertImage", attachment.uri);

                    ulong handler = 0;
                    handler = web_view.image_removed.connect ((uri) => {
                        if (uri == attachment.uri) {
                            attachment.destroy ();
                            web_view.disconnect (handler);
                        }
                    });
                } catch (Error e) {
                    var error_dialog = new Granite.MessageDialog (
                        _("Unable to insert image"),
                        _("There was an unexpected error while trying to insert the image."),
                        new ThemedIcon ("insert-image"),
                        Gtk.ButtonsType.CLOSE
                    ) {
                        badge_icon = new ThemedIcon ("dialog-error")
                    };
                    error_dialog.show_error_details (e.message);
                    error_dialog.present ();
                    error_dialog.response.connect (() => error_dialog.destroy ());
                }
            }

            filechooser.destroy ();
        });

        filechooser.show ();
    }

    private void on_mouse_target_changed (WebKit.WebView web_view, WebKit.HitTestResult hit_test, uint mods) {
        if (hit_test.context_is_link ()) {
            var url = hit_test.get_link_uri ();
            var hover_url = url != null ? GLib.Uri.unescape_string (url) : null;

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
        if (message.get_subject () != null) {
            subject_val.text = message.get_subject ();

            if (type == Type.REPLY || type == Type.REPLY_ALL) {
                // RFC 2822 makes the "Re: " string verbatim (so don't translate it)
                // also we have to make sure that the subject doesn't already contain it
                // before re-adding it.
                // https://datatracker.ietf.org/doc/html/rfc2822#section-3.6.5
                if (!subject_val.text.up ().contains ("RE: ")) {
                    subject_val.text = "Re: %s".printf (subject_val.text);
                }
            }
        }

        if (from_combo.model.iter_n_children (null) > 1) {
            bool found = false;

            if (type != DRAFT) {
                // Try to preselect the email address the message was sent to when replying.
                // This method is preferred to the fallback below because it handles aliases.
                Camel.InternetAddress recipients = new Camel.InternetAddress ();

                unowned var to_recipients = message.get_recipients (Camel.RECIPIENT_TYPE_TO);
                if (to_recipients != null) {
                    recipients.cat (to_recipients);
                }
                unowned var cc_recipients = message.get_recipients (Camel.RECIPIENT_TYPE_CC);
                if (cc_recipients != null) {
                    recipients.cat (cc_recipients);
                }
                unowned var bcc_recipients = message.get_recipients (Camel.RECIPIENT_TYPE_BCC);
                if (bcc_recipients != null) {
                    recipients.cat (bcc_recipients);
                }

                int i = 0;
                unowned string address;
                while (recipients.get (i, null, out address) && !found) {
                    i++;
                    from_combo.model.foreach ((model, path, iter) => {
                        GLib.Value value;
                        model.get_value (iter, 0, out value);

                        if (value.get_string () == address) {
                            from_combo.set_active_iter (iter);
                            found = true;
                            return true;
                        }

                        return false;
                    });
                }
            }

            // If no matching address was found fall back to using the address
            // associated with the E.Source the message belongs to
            if (!found) {
                unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();
                unowned var account_source_uid = message.get_source ();
                var account_source = session.ref_source (account_source_uid);

                if (account_source != null && account_source.has_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT)) {
                    unowned var account_extension = (E.SourceMailAccount) account_source.get_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT);

                    var identity_uid = account_extension.identity_uid;
                    if (identity_uid != null && identity_uid != "") {
                        var identity_source = session.ref_source (identity_uid);

                        if (identity_source != null && identity_source.has_extension (E.SOURCE_EXTENSION_MAIL_IDENTITY)) {
                            unowned var identity_extension = (E.SourceMailIdentity) identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_IDENTITY);

                            var identity_address = identity_extension.get_address ();
                            if (identity_address != "") {
                                from_combo.model.foreach ((model, path, iter) => {
                                    GLib.Value value;
                                    model.get_value (iter, 0, out value);

                                    if (value.get_string () == identity_address) {
                                        from_combo.set_active_iter (iter);
                                        return true;
                                    }

                                    return false;
                                });
                            }
                        }
                    }
                }
            }
        }

        if (content_to_quote != null) {
            if (type == Type.DRAFT) {
                ancestor_message_info = info;

                if (content_to_quote.contains ("elementary-message-body")) {
                    //We can assume the message was created using the elementary mail composer
                    //and has the necessary tags. Therefore we overwrite the blank templates
                    //whole html body
                    web_view.set_content_of_element ("body", content_to_quote);
                } else {
                    web_view.set_content_of_element ("#elementary-message-body", content_to_quote);
                }

                unowned var to = message.get_recipients (Camel.RECIPIENT_TYPE_TO);
                if (to != null) {
                    to_val.text = to.format ();
                }

                unowned var cc = message.get_recipients (Camel.RECIPIENT_TYPE_CC);
                if (cc != null) {
                    cc_val.text = cc.format ();

                    if (cc_val.text.length > 0) {
                        cc_revealer.reveal_child = true;
                    }
                }

                unowned var bcc = message.get_recipients (Camel.RECIPIENT_TYPE_BCC);
                if (bcc != null) {
                    bcc_val.text = bcc.format ();

                    if (bcc_val.text.length > 0) {
                        bcc_revealer.reveal_child = true;
                    }
                }
            } else {
                string message_content = "";
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

                    if (message.has_attachment ()) {
                        get_attachments.begin (message.content);
                    }
                }

                web_view.set_content_of_element ("#elementary-message-quote", message_content);
            }
        }
    }

    private async void get_attachments (Camel.DataWrapper message_content) {
        if (message_content is Camel.Multipart) {
            GLib.File? tmp_dir = null;
            unowned var content = (Camel.Multipart)message_content;
            for (uint i = 0; i < content.get_number (); i++) {
                unowned var part = content.get_part (i);
                unowned var field = part.get_mime_type_field ();
                if (part.get_content_disposition ().is_attachment (part.get_content_type ())) {
                    try {
                        if (tmp_dir == null) {
                            tmp_dir = GLib.File.new_for_path (GLib.DirUtils.make_tmp (".XXXXXX"));
                        }

                        var file = tmp_dir.get_child (part.get_filename ());
                        if (!file.query_exists ()) {
                            var output_stream = yield file.create_async (FileCreateFlags.NONE);
                            yield part.content.decode_to_output_stream (output_stream, GLib.Priority.DEFAULT, null);
                        }

                        attachment_box.add (new Attachment (file, Attachment.DISPOSITION_ATTACHMENT));
                        attachment_box.show_all ();
                    } catch (Error e) {
                        critical (e.message);
                    }
                } else if (field.type == "multipart") {
                    yield get_attachments (part.content);
                }
            }
        }
    }

    private void on_discard () {
        var discard_dialog = new Granite.MessageDialog (
            _("Permanently delete this draft?"),
            _("You cannot undo this action, nor recover your draft once it has been deleted."),
            new ThemedIcon ("mail-drafts"),
            Gtk.ButtonsType.NONE
        ) {
            badge_icon = new ThemedIcon ("edit-delete"),
            transient_for = this
        };

        discard_dialog.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        var discard_anyway = discard_dialog.add_button (_("Delete Draft"), Gtk.ResponseType.ACCEPT);
        discard_anyway.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        discard_dialog.present ();
        discard_dialog.response.connect ((response) => {
            if (response == Gtk.ResponseType.ACCEPT) {
                discard_draft = true;
                finished ();
                close ();
            }

            discard_dialog.destroy ();
        });
    }

    private void on_send () {
        send_message.begin ();
    }

    private async void send_message () {
        sensitive = false;

        if (subject_val.text == "") {
            var no_subject_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Send without subject?"),
                _("This message has an empty subject field. The recipient may be unable to infer its scope or importance."),
                "mail-send",
                Gtk.ButtonsType.NONE
            );
            no_subject_dialog.modal = true;
            no_subject_dialog.transient_for = this;

            no_subject_dialog.add_button (_("Don't Send"), Gtk.ResponseType.CANCEL);

            var send_anyway = no_subject_dialog.add_button (_("Send Anyway"), Gtk.ResponseType.ACCEPT);
            send_anyway.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

            no_subject_dialog.present ();
            no_subject_dialog.response.connect ((response) => {
                no_subject_dialog.destroy ();

                if (response == Gtk.ResponseType.CANCEL) {
                    sensitive = true;
                    return;
                }

                send_message.callback ();
            });

            yield;
        }

        unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();
        var body_html = yield web_view.get_body_html (true);
        var message = build_message (body_html);
        var sender = build_sender (message, from_combo.get_active_text ());
        var recipients = build_recipients (message, to_val.text, cc_val.text, bcc_val.text);

        remember_recipients.begin (recipients);

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
                warning_dialog.present ();
                warning_dialog.response.connect (() => warning_dialog.destroy ());
            }

            discard_draft = true;
            finished ();
            close ();
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
            error_dialog.present ();
            error_dialog.response.connect (() => error_dialog.destroy ());
        } finally {
            sensitive = true;
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

    private async void remember_recipients (Camel.InternetAddress recipients) {
        var contact_manager = ContactManager.get_default ();
        for (int i = 0; i < recipients.length (); i++) {
            string name;
            string address;
            recipients.get (i, out name, out address);
            yield contact_manager.remember_mail_address (address, name);
        }
    }

    private void load_from_combobox () {
        unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();
        foreach (var address in session.get_own_addresses ()) {
            from_combo.append_text (address);
        }

        from_combo.active = 0;
    }

    private void populate_signature_menu (Menu menu) {
        var manage_section = new Menu ();
        var manage_item = new MenuItem (_("Edit Signatures…"), Application.ACTION_PREFIX + Application.ACTION_MANAGE_SIGNATURES);
        manage_section.append_item (manage_item);

        var selection_section = new Menu ();
        selection_section.append (_("None"), Action.print_detailed_name (ACTION_PREFIX + ACTION_INSERT_SIGNATURE, "none"));

        unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();
        foreach (var signature_source in session.get_all_signature_sources ()) {
            selection_section.append (
                signature_source.display_name,
                Action.print_detailed_name (ACTION_PREFIX + ACTION_INSERT_SIGNATURE, signature_source.uid)
            );
        }

        menu.remove_all ();
        menu.append_section (null, manage_section);
        menu.append_section (null, selection_section);
    }

    private void on_insert_signature (Action action, Variant? parameter) {
        unowned var signature_uid = parameter.get_string ();

        if (signature_uid == "none") {
            web_view.set_content_of_element ("#elementary-message-signature", "");
            return;
        }

        unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();
        session.get_signature_for_uid.begin (signature_uid, (obj, res) => {
            var signature = session.get_signature_for_uid.end (res);
            web_view.set_content_of_element ("#elementary-message-signature", signature);
        });
    }

    private void set_default_signature_for_sender () {
        var sender = from_combo.get_active_text ();
        unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();
        activate_action (ACTION_INSERT_SIGNATURE, session.get_signature_uid_for_sender (sender));
    }

    private class Attachment : Gtk.FlowBoxChild {
        public const string DISPOSITION_ATTACHMENT = "attachment";
        public const string DISPOSITION_INLINE = "inline";

        public GLib.File file { get; construct; }
        public string disposition { get; construct; }
        public string cid { get; construct; }
        public string uri { get; construct; }

        private GLib.FileInfo? info;

        public Attachment (GLib.File file, string disposition) {
            Object (
                file: file,
                disposition: disposition
            );
        }

        construct {
            const string QUERY_STRING =
                GLib.FileAttribute.STANDARD_CONTENT_TYPE + "," +
                GLib.FileAttribute.STANDARD_DISPLAY_NAME + "," +
                GLib.FileAttribute.STANDARD_ICON + "," +
                GLib.FileAttribute.STANDARD_SIZE;

            cid = GLib.Uuid.string_random ();
            uri = "cid:%s".printf (cid);

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

            var box = new Gtk.Box (HORIZONTAL, 3) {
                margin_top = 3,
                margin_bottom = 3,
                margin_start = 3,
                margin_end = 3
            };
            box.add (image);
            box.add (name_label);
            box.add (size_label);
            box.add (remove_button);

            if (disposition == DISPOSITION_INLINE) {
                no_show_all = true;
            }

            margin_top = 3;
            margin_bottom = 3;
            margin_start = 3;
            margin_end = 3;
            add (box);

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

            var mimepart = new Camel.MimePart () {
                content_id = cid,
                disposition = disposition,
                content = wrapper
            };

            mimepart.set_filename (info.get_display_name ());

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

    public async bool save_draft () {
        if (discard_draft || !web_view.body_html_changed) {
            return false;
        }

        var body_html = yield web_view.get_body_html ();

        if (body_html != null) {
            unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();

            var message = build_message (body_html);
            var sender = build_sender (message, from_combo.get_active_text ());
            var recipients = build_recipients (message, to_val.text, cc_val.text, bcc_val.text);

            try {
                yield session.save_draft (message, sender, recipients, ancestor_message_info);
            } catch (Error e) {
                var error_dialog = new Granite.MessageDialog (
                    _("Unable to save draft"),
                    _("There was an unexpected error while saving your draft."),
                    new ThemedIcon ("mail-drafts"),
                    Gtk.ButtonsType.CLOSE
                ) {
                    badge_icon = new ThemedIcon ("dialog-error")
                };
                error_dialog.show_error_details (e.message);
                error_dialog.present ();
                error_dialog.response.connect (() => error_dialog.destroy ());
                return true;
            }
        }

        return false;
    }
}
