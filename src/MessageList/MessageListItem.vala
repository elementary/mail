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
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.MessageListItem : Gtk.ListBoxRow {
    public bool loaded { get; private set; }
    public Camel.MessageInfo message_info { get; construct; }
    public Camel.MimeMessage? mime_message { get; private set; default = null; }

    private Mail.MessageListBox parent_message_box;

    private Mail.WebView web_view;
    private GLib.Cancellable loading_cancellable;

    private Gtk.Revealer blocked_images_revealer;
    private Gtk.Button images_button_show;
    private Gtk.Button images_button_always_show;
    private Gtk.Revealer secondary_revealer;
    private Gtk.Stack header_stack;
    private Gtk.StyleContext style_context;
    private Adw.Avatar avatar;
    private Gtk.FlowBox attachment_bar = null;

    private string message_content;
    private bool message_is_html = false;
    private bool message_loaded = false;

    private static Gee.HashMap<string, Gdk.Pixbuf> avatars;
    private static GLib.Settings desktop_settings;

    public bool expanded {
        get {
            return secondary_revealer.reveal_child;
        }
        set {
            secondary_revealer.reveal_child = value;
            header_stack.set_visible_child_name (value ? "large" : "small");
            if (value) {
                if (!message_loaded) {
                    get_message.begin ();
                    message_loaded = true;
                }
                style_context.remove_class ("collapsed");
            } else {
                style_context.add_class ("collapsed");
            }
        }
    }

    private GLib.Settings settings;

    public MessageListItem (Camel.MessageInfo message_info, Mail.MessageListBox mbox) {
        Object (
            margin_start: 12,
            margin_end: 12,
            margin_top: 12,
            margin_bottom: 12,
            message_info: message_info
        );
        parent_message_box = mbox;
    }

    static construct {
        avatars = new Gee.HashMap<string, Gdk.Pixbuf> (null, null);
        desktop_settings = new GLib.Settings ("org.gnome.desktop.interface");
    }

    construct {
        loading_cancellable = new GLib.Cancellable ();

        style_context = get_style_context ();
        style_context.add_class (Granite.STYLE_CLASS_CARD);

        unowned string? parsed_address;
        unowned string? parsed_name;

        var camel_address = new Camel.InternetAddress ();
        camel_address.unformat (message_info.from);
        camel_address.get (0, out parsed_name, out parsed_address);

        if (parsed_name == null) {
            parsed_name = parsed_address;
        }

        avatar = new Adw.Avatar (48, parsed_name, true) {
            valign = Gtk.Align.START
        };

        var from_label = new Gtk.Label (_("From:"));
        from_label.halign = Gtk.Align.END;
        from_label.valign = Gtk.Align.START;
        from_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        var to_label = new Gtk.Label (_("To:"));
        to_label.halign = Gtk.Align.END;
        to_label.valign = Gtk.Align.START;
        to_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        var subject_label = new Gtk.Label (_("Subject:"));
        subject_label.halign = Gtk.Align.END;
        subject_label.valign = Gtk.Align.START;
        subject_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        var from_val_label = new Gtk.Label (message_info.from);
        from_val_label.wrap = true;
        from_val_label.xalign = 0;

        var to_val_label = new Gtk.Label (message_info.to);
        to_val_label.wrap = true;
        to_val_label.xalign = 0;

        var subject_val_label = new Gtk.Label (message_info.subject);
        subject_val_label.xalign = 0;
        subject_val_label.wrap = true;

        var fields_grid = new Gtk.Grid ();
        fields_grid.column_spacing = 6;
        fields_grid.row_spacing = 6;
        fields_grid.attach (from_label, 0, 0, 1, 1);
        fields_grid.attach (to_label, 0, 1, 1, 1);
        fields_grid.attach (subject_label, 0, 3, 1, 1);
        fields_grid.attach (from_val_label, 1, 0, 1, 1);
        fields_grid.attach (to_val_label, 1, 1, 1, 1);
        fields_grid.attach (subject_val_label, 1, 3, 1, 1);

        var cc_info = message_info.cc;
        if (cc_info != null) {
            var cc_label = new Gtk.Label (_("Cc:"));
            cc_label.halign = Gtk.Align.END;
            cc_label.valign = Gtk.Align.START;
            cc_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

            var cc_val_label = new Gtk.Label (cc_info);
            cc_val_label.xalign = 0;
            cc_val_label.wrap = true;

            fields_grid.attach (cc_label, 0, 2, 1, 1);
            fields_grid.attach (cc_val_label, 1, 2, 1, 1);
        }

        var small_from_label = new Gtk.Label (message_info.from);
        from_val_label.ellipsize = Pango.EllipsizeMode.END;
        from_val_label.xalign = 0;

        var small_fields_grid = new Gtk.Grid ();
        small_fields_grid.attach (small_from_label, 0, 0, 1, 1);

        header_stack = new Gtk.Stack ();
        header_stack.hhomogeneous = false;
        header_stack.vhomogeneous = false;
        header_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        header_stack.add_named (fields_grid, "large");
        header_stack.add_named (small_fields_grid, "small");

        var relevant_timestamp = message_info.date_received;
        if (relevant_timestamp == 0) {
            // Sent messages do not have a date_received timestamp.
            relevant_timestamp = message_info.date_sent;
        }

        var date_format = Granite.DateTime.get_default_date_format (false, true, true);
        var time_format = Granite.DateTime.get_default_time_format (desktop_settings.get_enum ("clock-format") == 1, false);

        ///TRANSLATORS: The first %s represents the date and the second %s the time of the message (either when it was received or sent)
        var datetime_label = new Gtk.Label (new DateTime.from_unix_utc (relevant_timestamp).to_local ().format (_("%s at %s").printf (date_format, time_format)));
        datetime_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        var starred_icon = new Gtk.Image ();
        starred_icon.add_css_class (Granite.STYLE_CLASS_MENU);

        if (Camel.MessageFlags.FLAGGED in (int) message_info.flags) {
            starred_icon.icon_name = "starred-symbolic";
            starred_icon.tooltip_text = _("Unstar message");
        } else {
            starred_icon.icon_name = "non-starred-symbolic";
            starred_icon.tooltip_text = _("Star message");
        }

        var starred_button = new Gtk.Button ();
        starred_button.child = starred_icon;
        starred_button.add_css_class (Granite.STYLE_CLASS_FLAT);

        var reply_item = new Gtk.Button.with_label (_("Reply"));
        reply_item.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        //reply_item.clicked.connect (() => add_inline_composer (ComposerWidget.Type.REPLY));

        var reply_all_item = new Gtk.Button.with_label (_("Reply to All"));
        reply_all_item.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        //reply_all_item.clicked.connect (() => add_inline_composer (ComposerWidget.Type.REPLY_ALL));

        var forward_item = new Gtk.Button.with_label (_("Forward"));
        forward_item.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        //forward_item.clicked.connect (() => add_inline_composer (ComposerWidget.Type.FORWARD));

        var separator_item = new Gtk.Separator (HORIZONTAL);

        var print_item = new Gtk.Button.with_label (_("Print…"));
        print_item.add_css_class (Granite.STYLE_CLASS_MENUITEM);
        print_item.clicked.connect (on_print);

        var actions_menu_box = new Gtk.Box (VERTICAL, 0);
        actions_menu_box.append (reply_item);
        actions_menu_box.append (reply_all_item);
        actions_menu_box.append (forward_item);
        actions_menu_box.append (separator_item);
        actions_menu_box.append (print_item);

        var actions_menu = new Gtk.Popover () {
            child = actions_menu_box
        };
        actions_menu.add_css_class (Granite.STYLE_CLASS_MENU);

        var actions_menu_button = new Gtk.MenuButton () {
            icon_name = "view-more-symbolic",
            tooltip_text = _("More"),
            margin_top = 6,
            valign = START,
            halign = END,
            popover = actions_menu
        };
        actions_menu_button.add_css_class (Granite.STYLE_CLASS_FLAT);
        //actions_menu_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var action_grid = new Gtk.Grid () {
            column_spacing = 3,
            hexpand = true,
            halign = END,
            valign = START
        };
        action_grid.attach (datetime_label, 0, 0);
        action_grid.attach (starred_button, 2, 0);
        action_grid.attach (actions_menu_button, 2, 1);

        var header = new Gtk.Grid () {
            column_spacing = 12,
            margin_start = 12,
            margin_end = 12,
            margin_top = 12,
            margin_bottom = 12
        };
        header.attach (avatar, 0, 0, 1, 3);
        header.attach (header_stack, 1, 0, 1, 3);
        header.attach (action_grid, 2, 0);

        var header_gesture_click = new Gtk.GestureClick ();
        header.add_controller (header_gesture_click);

        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        separator.hexpand = true;

        settings = new GLib.Settings ("io.elementary.mail");

        images_button_show = new Gtk.Button.with_label (_("Show Images"));
        images_button_always_show = new Gtk.Button.with_label (_("Always Show from Sender"));

        var images_button_box = new Gtk.Box (HORIZONTAL, 5) {
            halign = CENTER
        };
        images_button_box.append (images_button_show);
        images_button_box.append (images_button_always_show);

        var blocked_images_box = new Gtk.FlowBox () {
            margin_start = 12,
            margin_bottom = 12,
            margin_end = 12,
            margin_top = 12,
            hexpand = true,
            homogeneous = true,
            selection_mode = NONE
        };
        blocked_images_box.append (new Gtk.Label (_("This message contains remote images.")));
        blocked_images_box.append (images_button_box);
        //blocked_images_box.add_css_class (Granite.STYLE_CLASS_FRAME);
        blocked_images_box.add_css_class (Granite.STYLE_CLASS_WARNING);

        blocked_images_revealer = new Gtk.Revealer () {
            child = blocked_images_box
        };

        web_view = new Mail.WebView ();
        web_view.margin_start = 12;
        web_view.margin_end = 12;
        web_view.margin_top = 12;
        web_view.margin_bottom = 12;
        web_view.hexpand = true;
        web_view.vexpand = true;
        web_view.mouse_target_changed.connect (on_mouse_target_changed);
        web_view.context_menu.connect (on_webview_context_menu);
        web_view.load_finished.connect (() => {
            loaded = true;
        });

        var secondary_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        secondary_box.append (separator);
        secondary_box.append (blocked_images_revealer);
        secondary_box.append (web_view);

        secondary_revealer = new Gtk.Revealer ();
        secondary_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;
        secondary_revealer.set_child (secondary_box);

        var base_box = new Gtk.Box (VERTICAL, 0);
        base_box.hexpand = true;
        base_box.vexpand = true;
        base_box.append (header);
        base_box.append (secondary_revealer);

        if (Camel.MessageFlags.ATTACHMENTS in (int) message_info.flags) {
            var attachment_icon = new Gtk.Image.from_icon_name ("mail-attachment-symbolic");
            attachment_icon.add_css_class (Granite.STYLE_CLASS_MENU);
            attachment_icon.margin_start = 6;
            attachment_icon.tooltip_text = _("This message contains one or more attachments");
            action_grid.attach (attachment_icon, 1, 0);

            attachment_bar = new Gtk.FlowBox () {
                hexpand = true,
                homogeneous = true
            };
            //attachment_bar.add_css_class (Granite.STYLE_CLASS_TOOLBAR);
            //attachment_bar.add_css_class (Granite.STYLE_CLASS_INLINE_TOOLBAR);
            secondary_box.append (attachment_bar);
        }

        set_child (base_box);
        expanded = false;

        //avatar.set_loadable_icon (new GravatarIcon (parsed_address, get_style_context ().get_scale ()));

        // header_event_box.enter_notify_event.connect ((event) => {
        //     if (event.detail != Gdk.NotifyType.INFERIOR) {
        //         var window = header_event_box.get_window ();
        //         var cursor = new Gdk.Cursor.from_name (window.get_display (), "pointer");
        //         window.set_cursor (cursor);
        //     }
        // });

        // header_event_box.leave_notify_event.connect ((event) => {
        //     if (event.detail != Gdk.NotifyType.INFERIOR) {
        //         header_event_box.get_window ().set_cursor (null);
        //     }
        // });

        header_gesture_click.released.connect (() => {
            expanded = !expanded;
        });

        destroy.connect (() => {
            loading_cancellable.cancel ();
        });

        starred_button.clicked.connect (() => {
            if (Camel.MessageFlags.FLAGGED in (int) message_info.flags) {
                message_info.set_flags (Camel.MessageFlags.FLAGGED, 0);
                starred_icon.icon_name = "non-starred-symbolic";
                starred_icon.tooltip_text = _("Star message");
            } else {
                message_info.set_flags (Camel.MessageFlags.FLAGGED, ~0);
                starred_icon.icon_name = "starred-symbolic";
                starred_icon.tooltip_text = _("Unstar message");
            }
        });

        web_view.image_load_blocked.connect (() => {
            blocked_images_revealer.set_reveal_child (true);
        });
        web_view.link_activated.connect ((uri) => {
            try {
                AppInfo.launch_default_for_uri (uri, null);
            } catch (Error e) {
                warning ("Failed to open link: %s", e.message);
            }
        });
    }

    // private void add_inline_composer (ComposerWidget.Type composer_type) {
    //     var message_list_box = (MessageListBox) get_parent ();
    //     message_list_box.add_inline_composer.begin (composer_type, this);
    // }

    private void on_print () {
        try {
            var settings = new Gtk.PrintSettings ();
            /// Translators: This is the default file name of a printed email
            string filename = _("Email Message");

            unowned string subject = message_info.subject;
            if (subject != null && subject != "") {
                /* Replace any runs of whitespace, non-printing characters or slashes with a
                   single space and remove and leading or trailing spaces. */
                var sanitized_subject = new Regex ("[[:space:][:cntrl:]/]+").replace (subject, -1, 0, " ").strip ();
                if (sanitized_subject.length <= 64) {
                    filename = sanitized_subject;
                } else {
                    filename = "%s…".printf (sanitized_subject.substring (0, sanitized_subject.char_count (64 - 1)));
                }
            }

            settings.set (Gtk.PRINT_SETTINGS_OUTPUT_BASENAME, filename);

            /* @TODO: include header fields in printed output */
            var print_operation = new WebKit.PrintOperation (web_view);
            print_operation.set_print_settings (settings);
            print_operation.run_dialog ((Gtk.ApplicationWindow) get_root ());
        } catch (Error e) {
            var print_error_dialog = new Granite.MessageDialog.with_image_from_icon_name (
                _("Unable to print email"),
                _(""),
                "printer"
            );
            print_error_dialog.badge_icon = new ThemedIcon ("dialog-error");
            print_error_dialog.transient_for = (Gtk.Window) get_root ();
            print_error_dialog.show_error_details (e.message);
            print_error_dialog.response.connect (() => {
                print_error_dialog.destroy ();
            });
            print_error_dialog.present ();
        }
    }

    private void on_mouse_target_changed (WebKit.WebView web_view, WebKit.HitTestResult hit_test, uint mods) {
        if (hit_test.context_is_link ()) {
            parent_message_box.hovering_over_link (hit_test.get_link_label (), hit_test.get_link_uri ());
        } else {
            parent_message_box.hovering_over_link (null, null);
        }
    }

    private bool on_webview_context_menu (WebKit.ContextMenu menu, Gdk.Event event, WebKit.HitTestResult hit_test) {
        WebKit.ContextMenu new_context_menu = new WebKit.ContextMenu ();

        for (int i = 0; i < menu.get_n_items (); i++) {
            var item = menu.get_item_at_position (i);
            switch (item.get_stock_action ()) {
                case WebKit.ContextMenuAction.COPY_LINK_TO_CLIPBOARD:
                case WebKit.ContextMenuAction.COPY_IMAGE_URL_TO_CLIPBOARD:
                case WebKit.ContextMenuAction.COPY:
                    new_context_menu.append (item);
                    break;
                default:
                    break;
            }
        }

        menu.remove_all ();
        foreach (var item in new_context_menu.get_items ()) {
            menu.append (item);
        }

        menu.append (new WebKit.ContextMenuItem.from_stock_action (WebKit.ContextMenuAction.SELECT_ALL));

        return false;
    }

    private async void get_message () {
        var folder = message_info.summary.folder;
        Camel.MimeMessage? message = null;
        try {
            message = yield folder.get_message (message_info.uid, GLib.Priority.DEFAULT, loading_cancellable);
        } catch (Error e) {
            warning ("Could not get message. %s", e.message);
        }

        var flags = (Camel.FolderFlags)folder.get_flags ();

        if (!(Camel.FolderFlags.IS_JUNK in flags) && settings.get_boolean ("always-load-remote-images")) {
            web_view.load_images ();
        } else if (message != null) {
            var whitelist = settings.get_strv ("remote-images-whitelist");
            unowned string? sender;
            weak Camel.InternetAddress from = message.get_from ();
            if (from == null) {
                return;
            }

            from.@get (0, null, out sender);
            if (sender in whitelist) {
                web_view.load_images ();
            }

            images_button_show.clicked.connect (() => {
                web_view.load_images ();
                blocked_images_revealer.set_reveal_child (false);
            });

            images_button_always_show.clicked.connect (() => {
                if (!(sender in whitelist)) {
                    whitelist += sender;
                    settings.set_strv ("remote-images-whitelist", whitelist);
                }

                web_view.load_images ();
                blocked_images_revealer.set_reveal_child (false);
            });
        }

        if (message != null) {
            mime_message = message;
            yield open_message (message);
        }
    }

    private async void open_message (Camel.MimeMessage message) {
        yield parse_mime_content (message.content);
        if (message_is_html) {
            web_view.load_html (message_content);
        } else {
            /*
             * Instead of calling web_view.load_plain_text, use Camel's ToHTML
             * filter to convert text to HTML. This gives us some niceties like
             * clickable URLs and email addresses for free.
             *
             * Explanation of MimeFilterToHTMLFlags:
             * https://wiki.gnome.org/Apps/Evolution/Camel.MimeFilter#Camel.MimeFilterToHtml
             */
            var flags = Camel.MimeFilterToHTMLFlags.CONVERT_NL |
                Camel.MimeFilterToHTMLFlags.CONVERT_SPACES |
                Camel.MimeFilterToHTMLFlags.CONVERT_URLS |
                Camel.MimeFilterToHTMLFlags.CONVERT_ADDRESSES;
            var html = Camel.text_to_html (message_content, flags, 0);
            web_view.load_html (html);
        }
    }

    private async void parse_mime_content (Camel.DataWrapper mime_content) {
        if (mime_content is Camel.Multipart) {
            var content = mime_content as Camel.Multipart;
            for (uint i = 0; i < content.get_number (); i++) {
                var part = content.get_part (i);
                var field = part.get_mime_type_field ();
                if (part.disposition == "inline") {
                    yield handle_inline_mime (part);
                }
                if (field.type == "text") {
                    yield handle_text_mime (part.content);
                }
                if (part.disposition == "attachment") {
                    var button = new AttachmentButton (part, loading_cancellable);
                    button.activate.connect (() => show_attachment (button.mime_part));
                    attachment_bar.append (button);
                }
                if (field.type == "multipart") {
                    yield parse_mime_content (part.content);
                }
            }
        } else {
            yield handle_text_mime (mime_content);
        }
    }

    private async void handle_text_mime (Camel.DataWrapper part) {
        var field = part.get_mime_type_field ();
        if (message_content == null || (!message_is_html && field.subtype == "html")) {
            var os = new GLib.MemoryOutputStream.resizable ();
            try {
                yield part.decode_to_output_stream (os, GLib.Priority.DEFAULT, loading_cancellable);
                os.close ();
            } catch (Error e) {
                warning ("Possible error decoding email message: %s", e.message);
                return;
            }

            // Convert the message to UTF-8 to ensure we have a valid GLib string.
            message_content = convert_to_utf8 (os, field.param ("charset"));

            if (field.subtype == "html") {
                message_is_html = true;
            }
        }
    }

    private static string convert_to_utf8 (GLib.MemoryOutputStream os, string? encoding) {
        var num_bytes = (int) os.get_data_size ();
        var bytes = (string) os.steal_data ();

        string? utf8 = null;

        if (encoding != null) {
            string? iconv_encoding = Camel.iconv_charset_name (encoding);
            if (iconv_encoding != null) {
                try {
                    utf8 = GLib.convert (bytes, num_bytes, "UTF-8", iconv_encoding);
                } catch (ConvertError e) {
                    // Nothing to do - result will be assigned below.
                }
            }
        }

        if (utf8 == null || !utf8.validate ()) {
            /*
             * If message_content is not valid UTF-8 at this point, assume that
             * it is ISO-8859-1 encoded by default, and convert it to UTF-8.
             */
            try {
                utf8 = GLib.convert (bytes, num_bytes, "UTF-8", "ISO-8859-1");
            } catch (ConvertError e) {
                critical ("Every string should be valid ISO-8859-1. ConvertError: %s", e.message);
                utf8 = "";
            }
        }

        return utf8;
    }

    private async void handle_inline_mime (Camel.MimePart part) {
        if (part.get_content_id () == null) {
            return;
        }

        var byte_array = new ByteArray ();
        var os = new Camel.StreamMem ();
        os.set_byte_array (byte_array);
        try {
            yield part.content.decode_to_stream (os, GLib.Priority.DEFAULT, loading_cancellable);
        } catch (Error e) {
            warning ("Error decoding inline attachment: %s", e.message);
            return;
        }

        Bytes bytes = ByteArray.free_to_bytes (byte_array);
        var inline_stream = new MemoryInputStream.from_bytes (bytes);
        web_view.add_internal_resource (part.get_content_id (), inline_stream);
    }

    public async string get_message_body_html () {
        return yield web_view.get_body_html ();
    }

    private void show_attachment (Camel.MimePart attachment_part) {
        var dialog = new Mail.OpenAttachmentDialog (get_root () as Gtk.Window, attachment_part);
        dialog.response.connect (() => {
            dialog.destroy ();
        });
        dialog.present ();
    }
}
