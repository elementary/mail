// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
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
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class ConversationWidget : Gtk.ListBoxRow {
    public signal void open_attachment (Geary.Attachment attachment);
    public signal void save_attachments (Gee.List<Geary.Attachment> attachment);
    public signal void hovering_over_link (string? title, string? url);
    public signal void link_selected (string link);
    public signal void mark_read (bool read);
    public signal void star (bool starred);
    public signal void mark_load_remote_images ();
    public signal void edit_draft ();

    public Geary.Email email { get; private set; }
    public StylishWebView webview { get; private set; }
    public bool collapsable { get; set; default = true; }
    public bool collapsed {
        get {
            return content_revealer.child_revealed;
        }

        set {
            if (value == content_revealer.child_revealed) {
                toggle_view ();
            }
        }
    }

    // Internal class to associate inline image buffers (replaced by rotated scaled versions of
    // them) so they can be saved intact if the user requires it
    private class ReplacedImage : Geary.BaseObject {
        public string id;
        public string filename;
        public Geary.Memory.Buffer buffer;
        
        public ReplacedImage(int replaced_number, string filename, Geary.Memory.Buffer buffer) {
            id = "%X".printf(replaced_number);
            this.filename = filename;
            this.buffer = buffer;
        }
    }

    private const string[] INLINE_MIME_TYPES = {
        "image/png",
        "image/gif",
        "image/jpeg",
        "image/pjpeg",
        "image/bmp",
        "image/x-icon",
        "image/x-xbitmap",
        "image/x-xbm"
    };

    private const int MAX_INLINE_IMAGE_MAJOR_DIM = 1024;
    private const string REPLACED_IMAGE_CLASS = "replaced_inline_image";
    private const string DATA_IMAGE_CLASS = "data_inline_image";

    private weak Geary.Folder? current_folder = null;

    private string allow_prefix;
    private int next_replaced_buffer_number = 0;
    private Gee.HashSet<string> inlined_content_ids = new Gee.HashSet<string>();
    private Gee.HashMap<string, ReplacedImage> replaced_images = new Gee.HashMap<string, ReplacedImage>();
    private Gee.HashSet<string> replaced_content_ids = new Gee.HashSet<string>();
    private Gee.HashMap<string, string> replaced_images_index = new Gee.HashMap<string, string>();

    private Gtk.EventBox header;
    private Gtk.Stack header_fields_stack;
    private Gtk.Grid header_expanded_fields;
    private Gtk.Revealer content_revealer;
    private Gtk.Grid content_grid;

    private Granite.Widgets.Avatar avatar;

    private Gtk.Label user_name;
    private Gtk.Label user_mail;
    private Gtk.Label message_content;
    private Gtk.Label datetime;
    private Gtk.Button draft_edit_button;
    private Gtk.Button attachment_image;
    private Gtk.Button star_button;
    private Gtk.MenuButton menu_button;

    private Gtk.InfoBar info_bar;

    private Gtk.FlowBox attachments_box;

    public ConversationWidget (Geary.Email email, Geary.Folder? current_folder, bool is_in_folder) {
        this.email = email;
        this.current_folder = current_folder;

        // Populate the summary widgets
        var clock_format = GearyApplication.instance.config.clock_format;
        datetime.label = Date.pretty_print (email.date.value, clock_format);
        email.from.get_all ().foreach ((address) => {
            if (address.name != null) {
                user_name.label = "<b>%s</b>".printf (Markup.escape_text (address.name));
                user_mail.label = "<small>%s</small>".printf (Markup.escape_text (address.address));
            } else {
                user_name.label = "<b>%s</b>".printf (Markup.escape_text (address.address));
                user_mail.label = "";
            }

            return false;
        });

        try {
            var message = email.get_message ().get_preview ();
            message = message.replace ("\n", " ");
            message = message.replace ("\r \r", " ");
            message = message.replace ("\r", " ");
            message = message.replace ("  ", " ");
            message_content.label = Markup.escape_text (message);
        } catch (Error e) {
            debug ("Error adding message: %s", e.message);
        }

        // Populate the extended widgets
        insert_header_address(_("From:"), email.from, 0);

        int row_id = 1;
        if (email.to != null) {
            insert_header_address(_("To:"), email.to, row_id);
            row_id++;
        }

        if (email.cc != null) {
            insert_header_address(_("Cc:"), email.cc, row_id);
            row_id++;
        }

        if (email.bcc != null) {
            insert_header_address(_("Bcc:"), email.bcc, row_id);
            row_id++;
        }

        if (email.subject != null) {
            var title_label = new Gtk.Label (_("Subject:"));
            title_label.halign = Gtk.Align.END;
            title_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            var value_label = new Gtk.Label (email.subject.value);
            value_label.hexpand = true;
            ((Gtk.Misc) value_label).xalign = 0;
            value_label.wrap = true;
            header_expanded_fields.attach (title_label, 0, row_id, 1, 1);
            header_expanded_fields.attach (value_label, 1, row_id, 1, 1);
            row_id++;
        }

        if (email.date != null) {
            var title_label = new Gtk.Label (_("Date:"));
            title_label.halign = Gtk.Align.END;
            title_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            var value_label = new Gtk.Label (Date.pretty_print_verbose (email.date.value, clock_format));
            value_label.hexpand = true;
            ((Gtk.Misc) value_label).xalign = 0;
            header_expanded_fields.attach (title_label, 0, row_id, 1, 1);
            header_expanded_fields.attach (value_label, 1, row_id, 1, 1);
            row_id++;
        }

        // Add the avatar.
        try {
            Geary.RFC822.MailboxAddress? primary = email.get_message ().sender;
            if (primary != null) {
                var uri = Gravatar.get_image_uri (primary, Gravatar.Default.NOT_FOUND, 48 * scale_factor);
                var icon = new FileIcon (File.new_for_uri (uri));
                var icon_info = Gtk.IconTheme.get_default ().lookup_by_gicon_for_scale (icon, 48, scale_factor, 0);
                if (icon_info != null) {
                     icon_info.load_icon_async.begin (null, (obj, res) => {
                        try {
                            var pixbuf = icon_info.load_icon_async.end (res);
                            Idle.add (() => {
                                avatar.pixbuf = pixbuf;
                                return GLib.Source.REMOVE;
                            });
                        } catch (Error error) {
                            debug("Failed get URL: %s", error.message);
                        }
                     });
                }
            }
        } catch (Error error) {
            debug("Failed get URL: %s", error.message);
        }

        // Populate the view.
        if (email.body == null) {
            email.notify["body"].connect (open_message);
        } else {
            open_message ();
        }

        var menu = new Gtk.Menu ();
        var attachments = displayed_attachments ();
        if (attachments > 0) {
            var save_item = new Gtk.MenuItem.with_label (_("Save Attachment…"));
            if (attachments > 1) {
                save_item.label = _("Save All Attachments…");
            }

            save_item.activate.connect (() => save_attachments (email.attachments));
            menu.add (save_item);
            menu.add (new Gtk.SeparatorMenuItem ());
        }

        if (!in_drafts_folder ()) {
            var reply_item = new Gtk.MenuItem.with_label (_("Reply"));
            var reply_all_item = new Gtk.MenuItem.with_label (_("Reply to All"));
            var forward_item = new Gtk.MenuItem.with_label (_("Forward"));
            menu.add (reply_item);
            menu.add (reply_all_item);
            menu.add (forward_item);
            menu.add (new Gtk.SeparatorMenuItem ());
        }

        if (!is_in_folder || !in_drafts_folder ()) {
            draft_edit_button.destroy ();
        }

        var read_item = new Gtk.MenuItem.with_label (_("Mark as Read"));
        if (email.is_unread () == Geary.Trillian.FALSE) {
            read_item.label = _("Mark as Unread");
        }

        var print_item = new Gtk.MenuItem.with_label (_("Print…"));
        var source_item = new Gtk.MenuItem.with_label (_("View Source"));
        menu.add (read_item);
        menu.add (print_item);
        menu.add (new Gtk.SeparatorMenuItem ());
        menu.add (source_item);
        menu.show_all ();
        menu_button.popup = menu;

        read_item.activate.connect (() => {
            if (email.is_unread () == Geary.Trillian.FALSE) {
                read_item.label = _("Mark as Read");
                mark_read (false);
            } else {
                read_item.label = _("Mark as Unread");
                mark_read (true);
            }
        });

        if (displayed_attachments () > 0) {
            email.attachments.foreach ((attachment) => {
                var attachment_widget = new AttachmentWidget (attachment);
                attachment_widget.show_all ();
                attachment_widget.activate.connect (() => open_attachment (attachment));
                attachment_widget.save_as.connect (() => {
                    var attachment_list = new Gee.ArrayList<Geary.Attachment> ();
                    attachment_list.add (attachment);
                    save_attachments (attachment_list);
                });

                attachments_box.add (attachment_widget);
                return true;
            });
        } else {
            attachment_image.destroy ();
            attachments_box.no_show_all = true;
            attachments_box.hide ();
        }

        source_item.activate.connect (() => on_view_source ());
        print_item.activate.connect (() => on_print_message ());
    }

    construct {
        allow_prefix = random_string (10) + ":";
        margin = 12;
        margin_bottom = 3;
        get_style_context ().add_class ("card");
        get_style_context ().add_class ("collapsed");

        // Creating the Header
        var header_grid = new Gtk.Grid ();
        header_grid.orientation = Gtk.Orientation.HORIZONTAL;
        header_grid.margin = 6;
        header_grid.column_spacing = 6;

        header = new Gtk.EventBox ();
        header.events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        header.events |= Gdk.EventMask.KEY_PRESS_MASK;
        header.tooltip_text = _("Click to view the message");
        header.add (header_grid);

        avatar = new Granite.Widgets.Avatar.with_default_icon (48);
        avatar.valign = Gtk.Align.START;

        user_name = new Gtk.Label (null);
        ((Gtk.Misc) user_name).xalign = 0;
        user_name.valign = Gtk.Align.BASELINE;
        user_name.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        user_name.use_markup = true;

        user_mail = new Gtk.Label (null);
        user_mail.ellipsize = Pango.EllipsizeMode.END;
        ((Gtk.Misc) user_mail).xalign = 0;
        user_mail.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        user_mail.hexpand = true;
        user_mail.use_markup = true;
        user_mail.valign = Gtk.Align.BASELINE;

        message_content = new Gtk.Label (null);
        message_content.hexpand = true;
        message_content.ellipsize = Pango.EllipsizeMode.END;
        message_content.use_markup = true;
        ((Gtk.Misc) message_content).xalign = 0;
        message_content.single_line_mode = true;
        message_content.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        datetime = new Gtk.Label (null);
        datetime.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        datetime.halign = Gtk.Align.END;
        datetime.valign = Gtk.Align.END;

        var header_summary_fields = new Gtk.Grid ();
        header_summary_fields.column_spacing = 6;
        header_summary_fields.row_spacing = 6;
        header_summary_fields.margin_top = 12;
        header_summary_fields.margin_bottom = 12;
        header_summary_fields.attach (user_name, 0, 0, 1, 1);
        header_summary_fields.attach (user_mail, 1, 0, 1, 1);
        header_summary_fields.attach (datetime, 2, 0, 1, 1);
        header_summary_fields.attach (message_content, 0, 1, 3, 1);

        header_expanded_fields = new Gtk.Grid ();
        header_expanded_fields.column_spacing = 6;
        header_expanded_fields.row_spacing = 6;
        header_expanded_fields.margin_top = 12;
        header_expanded_fields.no_show_all = true;

        header_fields_stack = new Gtk.Stack ();
        header_fields_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        header_fields_stack.add_named (header_summary_fields, "summary");
        header_fields_stack.add_named (header_expanded_fields, "expanded");

        draft_edit_button = new Gtk.Button.from_icon_name ("edit-symbolic", Gtk.IconSize.MENU);
        draft_edit_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        draft_edit_button.margin_top = 6;
        draft_edit_button.valign = Gtk.Align.START;
        draft_edit_button.halign = Gtk.Align.END;
        draft_edit_button.tooltip_text = _("Edit Draft");
        draft_edit_button.clicked.connect (() => edit_draft ());

        attachment_image = new Gtk.Button.from_icon_name ("mail-attachment-symbolic", Gtk.IconSize.MENU);
        attachment_image.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        attachment_image.margin_top = 6;
        attachment_image.valign = Gtk.Align.START;
        attachment_image.halign = Gtk.Align.END;
        attachment_image.sensitive = false;
        attachment_image.tooltip_text = _("This message contains one or more attachments");

        star_button = new Gtk.Button.from_icon_name ("non-starred-symbolic", Gtk.IconSize.MENU);
        star_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        star_button.margin_top = 6;
        star_button.valign = Gtk.Align.START;
        star_button.halign = Gtk.Align.END;
        star_button.clicked.connect (() => {
            var star_image = (Gtk.Image) star_button.image;
            var new_state = (star_image.icon_name != "starred-symbolic");
            star (new_state);
            if (new_state) {
                star_image.icon_name = "starred-symbolic";
            } else {
                star_image.icon_name = "non-starred-symbolic";
            }
        });

        menu_button = new Gtk.MenuButton ();
        menu_button.image = new Gtk.Image.from_icon_name ("view-more-symbolic", Gtk.IconSize.MENU);
        menu_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        menu_button.margin_top = 6;
        menu_button.valign = Gtk.Align.START;
        menu_button.halign = Gtk.Align.END;

        header_grid.add (avatar);
        header_grid.add (header_fields_stack);
        header_grid.add (draft_edit_button);
        header_grid.add (attachment_image);
        header_grid.add (star_button);
        header_grid.add (menu_button);

        info_bar = new Gtk.InfoBar ();
        info_bar.no_show_all = true;
        info_bar.message_type = Gtk.MessageType.WARNING;
        info_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_FRAME);
        var action_area = (Gtk.Box) info_bar.get_action_area ();
        action_area.orientation = Gtk.Orientation.VERTICAL;
        info_bar.add_action_widget (new Gtk.Button.with_label (_("Show Images")), 1);
        info_bar.add_action_widget (new Gtk.Button.with_label (_("Always Show from Sender")), 2);
        info_bar.get_content_area ().add (new Gtk.Label (_("This message contains remote images.")));
        info_bar.response.connect ((id) => {
            if (id == 2) {
                show_images_from ();
            } else {
                show_images_email (false);
            }
        });

        webview = new StylishWebView ();
        webview.expand = true;
        webview.transparent = true;
        webview.hovering_over_link.connect (on_hovering_over_link);
        webview.context_menu.connect(() => { return true; }); // Suppress default context menu.
        webview.resource_request_starting.connect (on_resource_request_starting);
        webview.navigation_policy_decision_requested.connect (on_navigation_policy_decision_requested);
        webview.new_window_policy_decision_requested.connect (on_navigation_policy_decision_requested);

        attachments_box = new Gtk.FlowBox ();
        attachments_box.hexpand = true;
        attachments_box.activate_on_single_click = true;
        attachments_box.get_style_context ().add_class (Gtk.STYLE_CLASS_TOOLBAR);
        attachments_box.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);

        content_grid = new Gtk.Grid ();
        content_grid.margin = 6;
        content_grid.row_spacing = 6;
        content_grid.orientation = Gtk.Orientation.VERTICAL;
        content_grid.add (info_bar);
        content_grid.add (webview);

        var outside_grid = new Gtk.Grid ();
        outside_grid.row_spacing = 6;
        outside_grid.orientation = Gtk.Orientation.VERTICAL;
        outside_grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        outside_grid.add (content_grid);
        outside_grid.add (attachments_box);

        content_revealer = new Gtk.Revealer ();
        content_revealer.no_show_all = true;
        content_revealer.set_reveal_child (false);
        content_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;
        content_revealer.add (outside_grid);

        header.button_press_event.connect ((event) => header_button_press_event (event));
        header.key_press_event.connect ((event) => header_key_press_event (event));
        header.realize.connect (() => {
            var window = header.get_window ();
            if (collapsable) {
                window.cursor = new Gdk.Cursor.for_display (window.get_display (), Gdk.CursorType.HAND1);
            } else {
                window.cursor = new Gdk.Cursor.for_display (window.get_display (), Gdk.CursorType.ARROW);
            }
        });

        notify["collapsable"].connect (() => {
            var window = header.get_window ();
            header.tooltip_text = null;
            if (collapsable) {
                window.cursor = new Gdk.Cursor.for_display (window.get_display (), Gdk.CursorType.HAND1);
            } else {
                collapsed = false;
                window.cursor = new Gdk.Cursor.for_display (window.get_display (), Gdk.CursorType.ARROW);
            }
        });

        var main_grid = new Gtk.Grid ();
        main_grid.orientation = Gtk.Orientation.VERTICAL;
        main_grid.add (header);
        main_grid.add (content_revealer);

        add (main_grid);

        GearyApplication.instance.config.settings.changed[Configuration.GENERALLY_SHOW_REMOTE_IMAGES_KEY].connect(on_show_images_change);
    }

    public override bool draw (Cairo.Context cr) {
        int width = get_allocated_width ();
        int height = get_allocated_height ();
        unowned Gtk.StyleContext style_context = get_style_context ();
        style_context.render_background (cr, 0, 0, width, height);
        style_context.render_frame (cr, 0, 0, width, height);
        return base.draw (cr);
    }

    private void insert_header_address (string title, Geary.RFC822.MailboxAddresses? addresses, int index) {
        if (addresses == null)
            return;

        int i = 0;
        string value = "";
        Gee.List<Geary.RFC822.MailboxAddress> list = addresses.get_all ();
        foreach (Geary.RFC822.MailboxAddress a in list) {
            value += "<a href='mailto:%s'>".printf(Uri.escape_string (a.to_rfc822_string()));
            if (!Geary.String.is_empty (a.name)) {
                if (get_direction () == Gtk.TextDirection.RTL) {
                    value += "<small>%s</small>".printf (Geary.HTML.escape_markup (a.address));
                    value += " <b>%s</b>".printf (Geary.HTML.escape_markup (a.name));
                } else {
                    value += "<b>%s</b> ".printf (Geary.HTML.escape_markup (a.name));
                    value += "<small>%s</small>".printf (Geary.HTML.escape_markup (a.address));
                }
            } else {
                value += Geary.HTML.escape_markup (a.address);
            }

            value += "</a>";

            if (++i < list.size) {
                value += ", ";
            }
        }

        var title_label = new Gtk.Label (title);
        title_label.halign = Gtk.Align.END;
        title_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        var value_label = new Gtk.Label (value);
        value_label.hexpand = true;
        value_label.ellipsize = Pango.EllipsizeMode.END;
        value_label.use_markup = true;
        ((Gtk.Misc) value_label).xalign = 0;
        header_expanded_fields.attach (title_label, 0, index, 1, 1);
        header_expanded_fields.attach (value_label, 1, index, 1, 1);
    }

    private bool header_button_press_event (Gdk.EventButton event) {
        if (collapsable) {
            toggle_view ();
        }
        return true;
    }

    private bool header_key_press_event (Gdk.EventKey event) {
        if (event.state == 0 && event.keyval == Gdk.Key.KP_Enter && collapsable) {
            toggle_view ();
            return true;
        }

        return false;
    }

    private void toggle_view () {
        if (content_revealer.child_revealed) {
            get_style_context ().add_class ("collapsed");
            content_revealer.no_show_all = true;
            header_expanded_fields.no_show_all = true;
            header_fields_stack.set_visible_child_name ("summary");
            header_expanded_fields.hide ();
            content_revealer.set_reveal_child (false);
            header.tooltip_text = _("Click to view the message");
            Timeout.add (content_revealer.transition_duration, () => {
                content_revealer.hide ();
                return GLib.Source.REMOVE;
            });
        } else {
            get_style_context ().remove_class ("collapsed");
            content_revealer.no_show_all = false;
            content_revealer.show_all ();
            header_expanded_fields.no_show_all = false;
            header_expanded_fields.show_all ();
            header_fields_stack.set_visible_child_name ("expanded");
            content_revealer.set_reveal_child (true);
            if (collapsable) {
                header.tooltip_text = _("Click to hide the message");
            }
        }
    }

    [CCode (instance_pos = -1)]
    private void on_resource_request_starting (WebKit.WebFrame web_frame,
        WebKit.WebResource web_resource, WebKit.NetworkRequest request,
        WebKit.NetworkResponse? response) {
        if (response != null) {
            // A request that was previously approved resulted in a redirect.
            return;
        }

        string? uri = request.get_uri ();
        if (uri != null && !uri.has_prefix ("data:")) {
            if (uri.has_prefix (allow_prefix)) {
                request.set_uri (uri.substring (allow_prefix.length));
            } else {
                request.set_uri ("about:blank");
            }
        }
    }

    [CCode (instance_pos = -1)]
    private bool on_navigation_policy_decision_requested (WebKit.WebFrame frame,
        WebKit.NetworkRequest request, WebKit.WebNavigationAction navigation_action,
        WebKit.WebPolicyDecision policy_decision) {
        policy_decision.ignore ();

        // Other policy-decisions may be requested for various reasons. The existence of an iframe,
        // for example, causes a policy-decision request with an "OTHER" reason. We don't want to
        // open a webpage in the browser just because an email contains an iframe.
        if (navigation_action.reason == WebKit.WebNavigationReason.LINK_CLICKED)
            link_selected (request.uri);
        return true;
    }

    [CCode (instance_pos = -1)]
    private void on_hovering_over_link (string? title, string? url) {
        hovering_over_link (title, url);
    }

    private void open_message () {
        email.notify["body"].disconnect (open_message);
        Geary.RFC822.Message? message = null;
        try {
            message = email.get_message ();
        } catch (Error e) {
            debug("Could not get message. %s", e.message);
            return;
        }

        //
        // Build an HTML document from the email with two passes:
        //
        // * Geary.RFC822.Message.get_body() recursively walks the message's MIME structure looking
        //   for text MIME parts and assembles them sequentially.  If non-text MIME parts are
        //   discovered, it calls inline_image_replacer(), which
        //   converts them to an IMG tag with a data: URI if they are a supported image type.
        //   Otherwise, the MIME part is dropped.
        //
        // * insert_html_markup() then strips everything outside the BODY, turning the BODY tag
        //   itself into a DIV, and performs other massaging of the HTML.  It also looks for IMG
        //   tags that refer to other MIME parts via their Content-ID, converts them to data: URIs,
        //   and inserts them into the document.
        //
        // Attachments are generated and added in add_message(), which calls this method before
        // building the HTML for them.  The above two steps take steps to avoid inlining images
        // that are actually attachments (in particular, get_body() considers their
        // Content-Disposition)
        //

        try {
            var body_text = message.get_body (Geary.RFC822.TextFormat.HTML, inline_image_replacer) ?? "";
            bool remote_images;
            body_text = insert_html_markup (body_text, message, out remote_images);
            webview.get_dom_document ().body.set_inner_html (body_text);
            if (remote_images) {
                var contact = current_folder.account.get_contact_store ().get_by_rfc822 (email.get_primary_originator ());
                bool always_load = contact != null && contact.always_load_remote_images ();
                always_load |= GearyApplication.instance.config.generally_show_remote_images;
                if (current_folder.special_folder_type != Geary.SpecialFolderType.SPAM &&
                    always_load || email.load_remote_images ().is_certain ()) {
                        show_images_email (false);
                } else {
                    info_bar.no_show_all = false;
                    info_bar.show_all ();
                }
            }

            return;
        } catch (Error err) {
            if (err is Geary.RFC822Error.NOT_FOUND) {
                debug ("Could not get message html body text. %s", err.message);
            }
        }
    }

    private static bool is_content_type_supported_inline (Geary.Mime.ContentType content_type) {
        foreach (string mime_type in INLINE_MIME_TYPES) {
            try {
                if (content_type.is_mime_type (mime_type)) {
                    return true;
                }
            } catch (Error err) {
                debug ("Unable to compare MIME type %s: %s", mime_type, err.message);
            }
        }

        return false;
    }

    // This delegate is called from within Geary.RFC822.Message.get_body while assembling the plain
    // or HTML document when a non-text MIME part is encountered.
    // If this returns null, the MIME part is dropped from the final returned document; otherwise,
    // this returns HTML that is placed into the document in the position where the MIME part was
    // found
    private string? inline_image_replacer(string filename, Geary.Mime.ContentType? content_type,
        Geary.Mime.ContentDisposition? disposition, string? content_id, Geary.Memory.Buffer buffer) {
        if (content_type == null) {
            debug ("Not displaying inline: no Content-Type");
            return null;
        }

        if (!is_content_type_supported_inline (content_type)) {
            debug("Not displaying %s inline: unsupported Content-Type", content_type.to_string ());
            return null;
        }

        // Even if the image doesn't need to be rotated, there's a win here: by reducing the size
        // of the image at load time, it reduces the amount of work that has to be done to insert
        // it into the HTML and then decoded and displayed for the user ... note that we currently
        // have the doucment set up to reduce the size of the image to fit in the viewport, and a
        // scaled load-and-deode is always faster than load followed by scale.
        Geary.Memory.Buffer rotated_image = buffer;
        string mime_type = content_type.get_mime_type ();
        try {
            Gdk.PixbufLoader loader = new Gdk.PixbufLoader ();
            loader.size_prepared.connect (on_inline_image_size_prepared);

            Geary.Memory.UnownedBytesBuffer? unowned_buffer = buffer as Geary.Memory.UnownedBytesBuffer;
            if (unowned_buffer != null) {
                loader.write (unowned_buffer.to_unowned_uint8_array ());
            } else {
                loader.write (buffer.get_uint8_array ());
            }

            loader.close ();
            Gdk.Pixbuf? pixbuf = loader.get_pixbuf ();
            if (pixbuf != null) {
                pixbuf = pixbuf.apply_embedded_orientation ();
                // trade-off here between how long it takes to compress the data and how long it
                // takes to turn it into Base-64 (coupled with how long it takes WebKit to then
                // Base-64 decode and uncompress it)
                uint8[] image_data;
                pixbuf.save_to_buffer (out image_data, "png", "compression", "5");

                // Save length before transferring ownership (which frees the array)
                int image_length = image_data.length;
                rotated_image = new Geary.Memory.ByteBuffer.take ((owned) image_data, image_length);
                mime_type = "image/png";
            }
        } catch (Error err) {
            debug ("Unable to load and rotate image %s for display: %s", filename, err.message);
        }

        // store so later processing of the message doesn't replace this element with the original
        // MIME part
        string? escaped_content_id = null;
        if (!Geary.String.is_empty (content_id)) {
            replaced_content_ids.add (content_id);
            escaped_content_id = Geary.HTML.escape_markup (content_id);
        }

        // Store the original buffer and its filename in a local map so they can be recalled later
        // (if the user wants to save it) ... note that Content-ID is optional and there's no
        // guarantee that filename will be unique, even in the same message, so need to generate
        // a unique identifier for each object
        var replaced_image = new ReplacedImage (next_replaced_buffer_number++, filename, buffer);
        replaced_images.set (replaced_image.id, replaced_image);

        if (!Geary.String.is_empty (content_id)) {
            replaced_images_index.set (content_id, replaced_image.id);
        }

        return "<img alt=\"%s\" class=\"%s %s\" src=\"%s\" replaced-id=\"%s\" %s />".printf (
            Geary.HTML.escape_markup (filename),
            DATA_IMAGE_CLASS, REPLACED_IMAGE_CLASS,
            assemble_data_uri (mime_type, rotated_image),
            Geary.HTML.escape_markup (replaced_image.id),
            escaped_content_id != null ? @"cid=\"$escaped_content_id\"" : "");
    }

    // Called by Gdk.PixbufLoader when the image's size has been determined but not loaded yet ...
    // this allows us to load the image scaled down, for better performance when manipulating and
    // writing the data URI for WebKit
    private static void on_inline_image_size_prepared (Gdk.PixbufLoader loader, int width, int height) {
        // easier to use as local variable than have the const listed everywhere in the code
        // IN ALL SCREAMING CAPS
        int scale = MAX_INLINE_IMAGE_MAJOR_DIM;
        
        // Borrowed liberally from Shotwell's Dimensions.get_scaled() method
        
        // check for existing fit
        if (width <= scale && height <= scale) {
            return;
        }

        int adj_width, adj_height;
        if ((width - scale) > (height - scale)) {
            double aspect = (double) scale / (double) width;

            adj_width = scale;
            adj_height = (int) Math.round ((double) height * aspect);
        } else {
            double aspect = (double) scale / (double) height;

            adj_width = (int) Math.round ((double) width * aspect);
            adj_height = scale;
        }

        loader.set_size (adj_width, adj_height);
    }

    private string insert_html_markup (string text, Geary.RFC822.Message message, out bool remote_images) {
        remote_images = false;
        try {
            string inner_text = text;
            
            // If email HTML has a BODY, use only that
            GLib.Regex body_regex = new GLib.Regex ("<body([^>]*)>(.*)</body>", GLib.RegexCompileFlags.DOTALL);
            GLib.MatchInfo matches;
            if (body_regex.match(text, 0, out matches)) {
                inner_text = matches.fetch (2);
                string attrs = matches.fetch (1);
                if (attrs != "")
                    inner_text = @"<div$attrs>$inner_text</div>";
            }
            
            // Create a workspace for manipulating the HTML.
            WebKit.DOM.HTMLElement container = create_div ();
            container.set_inner_html (inner_text);
            

            // Now look for the signature.
            wrap_html_signature (ref container);

            // Then look for all <img> tags. Inline images are replaced with
            // data URLs.
            WebKit.DOM.NodeList inline_list = container.query_selector_all ("img");
            for (ulong i = 0; i < inline_list.length; ++i) {
                // Get the MIME content for the image.
                var img = (WebKit.DOM.HTMLImageElement) inline_list.item (i);
                string? src = img.get_attribute ("src");
                if (Geary.String.is_empty (src))
                    continue;
                
                // if no Content-ID, then leave as-is, but note if a non-data: URI is being used for
                // purposes of detecting remote images
                string? content_id = src.has_prefix ("cid:") ? src.substring (4) : null;
                if (Geary.String.is_empty (content_id)) {
                    remote_images = remote_images || !src.has_prefix ("data:");
                    
                    continue;
                }
                
                // if image has a Content-ID and it's already been replaced by the image replacer,
                // drop this tag, otherwise fix up this one with the Base-64 data URI of the image
                // and the replaced id
                if (!src.has_prefix ("data:")) {
                    string? filename = message.get_content_filename_by_mime_id (content_id);
                    Geary.Memory.Buffer image_content = message.get_content_by_mime_id (content_id);
                    Geary.Memory.UnownedBytesBuffer? unowned_buffer = image_content as Geary.Memory.UnownedBytesBuffer;

                    // Get the content type.
                    string guess;
                    if (unowned_buffer != null) {
                        guess = ContentType.guess (null, unowned_buffer.to_unowned_uint8_array (), null);
                    } else {
                        guess = ContentType.guess (null, image_content.get_uint8_array (), null);
                    }

                    string mimetype = ContentType.get_mime_type (guess);

                    // Replace the SRC to a data URI, the class to a known label for the popup menu,
                    // the ALT to its filename, if supplied and add the replaced-id
                    img.set_attribute ("src", assemble_data_uri (mimetype, image_content));
                    img.set_attribute ("class", DATA_IMAGE_CLASS);
                    if (!Geary.String.is_empty (filename)) {
                        img.set_attribute("alt", filename);
                    }

                    // FIXME: bugzilla.gnome.org 762782
                    // in case content_id has a trailing period it gets removed
                    // this is necessary as g_mime_object_get_content_id removes it too
                    if (content_id.has_suffix (".")) {
                        string content_id_without_suffix;
                        content_id_without_suffix = content_id.slice(0,content_id.length-1);
                        img.set_attribute ("replaced-id", replaced_images_index.get (content_id_without_suffix));
                    } else {
                        img.set_attribute ("replaced-id", replaced_images_index.get (content_id));
                    }

                    // stash here so inlined image isn't listed as attachment (esp. if it has no
                    // Content-Disposition)
                    inlined_content_ids.add (content_id);
                } else {
                    // replaced by data: URI, remove this tag and let the inserted one shine through
                    img.parent_element.remove_child (img);
                }
            }
            
            // Remove any inline images that were referenced through Content-ID
            foreach (string cid in inlined_content_ids) {
                try {
                    string escaped_cid = Geary.HTML.escape_markup (cid);
                    WebKit.DOM.Element? img = container.query_selector (@"[cid='$escaped_cid']");
                    if (img != null) {
                        img.parent_element.remove_child (img);
                    }
                } catch (Error error) {
                    debug ("Error removing inlined image: %s", error.message);
                }
            }

            // Now return the whole message.
            return container.get_inner_html();
        } catch (Error e) {
            debug("Error modifying HTML message: %s", e.message);
            return text;
        }
    }

    private void wrap_html_signature (ref WebKit.DOM.HTMLElement container) throws Error {
        // Most HTML signatures fall into one of these designs which are handled by this method:
        //
        // 1. GMail:            <div>-- </div>$SIGNATURE
        // 2. GMail Alternate:  <div><span>-- </span></div>$SIGNATURE
        // 3. Thunderbird:      <div>-- <br>$SIGNATURE</div>
        //
        WebKit.DOM.NodeList div_list = container.query_selector_all ("div,span,p");
        int i = 0;
        Regex sig_regex = new Regex ("^--\\s*$");
        Regex alternate_sig_regex = new Regex ("^--\\s*(?:<br|\\R)");
        for (; i < div_list.length; ++i) {
            // Get the div and check that it starts a signature block and is not inside a quote.
            WebKit.DOM.HTMLElement div = div_list.item(i) as WebKit.DOM.HTMLElement;
            string inner_html = div.get_inner_html();
            if ((sig_regex.match (inner_html) || alternate_sig_regex.match (inner_html)) &&
                !node_is_child_of (div, "BLOCKQUOTE")) {
                break;
            }
        }

        // If we have a signature, move it and all of its following siblings that are not quotes
        // inside a signature div.
        if (i == div_list.length) {
            return;
        }

        WebKit.DOM.Node elem = div_list.item (i) as WebKit.DOM.Node;
        WebKit.DOM.Element parent = elem.get_parent_element ();
        WebKit.DOM.HTMLElement signature_container = create_div ();
        signature_container.set_attribute ("class", "signature");
        do {
            // Get its sibling _before_ we move it into the signature div.
            WebKit.DOM.Node? sibling = elem.get_next_sibling ();
            signature_container.append_child (elem);
            elem = sibling;
        } while (elem != null);

        parent.append_child (signature_container);
    }

    public WebKit.DOM.HTMLDivElement create_div () throws Error {
        return webview.get_dom_document ().create_element ("div") as WebKit.DOM.HTMLDivElement;
    }

    private bool should_show_attachment (Geary.Attachment attachment) {
        // if displayed inline, don't include in attachment list
        if (attachment.content_id in inlined_content_ids) {
            return false;
        }

        switch (attachment.content_disposition.disposition_type) {
            case Geary.Mime.DispositionType.ATTACHMENT:
                return true;
            case Geary.Mime.DispositionType.INLINE:
                return !is_content_type_supported_inline (attachment.content_type);
            default:
                assert_not_reached ();
        }
    }

    private int displayed_attachments () {
        int ret = 0;
        email.attachments.foreach ((attachment) => {
            if (should_show_attachment (attachment)) {
                ret++;
            }

            return true;
        });

        return ret;
    }

    private void on_view_source () {
        string source = email.header.buffer.to_string () + email.body.buffer.to_string ();
        try {
            string temporary_filename;
            int temporary_handle = FileUtils.open_tmp ("geary-message-XXXXXX.txt", out temporary_filename);
            FileUtils.set_contents (temporary_filename, source);
            FileUtils.close (temporary_handle);

            // ensure this file is only readable by the user… this needs to be done after the file is closed
            FileUtils.chmod (temporary_filename, (int) (Posix.S_IRUSR | Posix.S_IWUSR));

            string temporary_uri = Filename.to_uri (temporary_filename, null);
            Gtk.show_uri (webview.get_screen (), temporary_uri, Gdk.CURRENT_TIME);
        } catch (Error error) {
            ErrorDialog dialog = new ErrorDialog (GearyApplication.instance.controller.main_window,
                _("Failed to open default text editor."), error.message);
            dialog.run ();
        }
    }

    private void on_print_message () {
        webview.get_main_frame ().print ();
    }

    private bool in_drafts_folder () {
        return current_folder != null && current_folder.special_folder_type == Geary.SpecialFolderType.DRAFTS;
    }

    private void show_images_from () {
        Geary.ContactStore contact_store = current_folder.account.get_contact_store();
        Geary.Contact? contact = contact_store.get_by_rfc822(email.get_primary_originator());
        if (contact == null) {
            debug("Couldn't find contact for %s", email.from.to_string());
            return;
        }
        
        Geary.ContactFlags flags = new Geary.ContactFlags();
        flags.add(Geary.ContactFlags.ALWAYS_LOAD_REMOTE_IMAGES);
        Gee.ArrayList<Geary.Contact> contact_list = new Gee.ArrayList<Geary.Contact>();
        contact_list.add(contact);
        contact_store.mark_contacts_async.begin(contact_list, flags, null);
        show_images_email (false);
    }

    private void show_images_email (bool remember) {
        try {
            WebKit.DOM.HTMLCollection nodes = webview.get_dom_document ().images;
            for (ulong i = 0; i < nodes.length; i++) {
                var element = nodes.item (i) as WebKit.DOM.Element;
                if (element == null || !element.has_attribute ("src")) {
                    continue;
                }

                string src = element.get_attribute ("src");
                if (src != null && !src.has_prefix ("data:")) {
                    element.set_attribute ("src", allow_prefix + src);
                }
            }
        } catch (Error error) {
            warning ("Error showing images: %s", error.message);
        }

        info_bar.hide ();
        if (remember) {
            // only add flag to load remote images if not already present
            if (email != null && !email.load_remote_images ().is_certain ()) {
                mark_load_remote_images ();
            }
        }
    }

    private void on_show_images_change () {
        // When the setting is changed to 'show images', the currently selected message is updated.
        // When the setting is changed to 'do not show images' the method returns, as there is no benefit
        // in 'unloading' images (like saving bandwidth or relating to security concerns).
        if (!GearyApplication.instance.config.generally_show_remote_images) {
            return;
        }

        if (email == null || current_folder.special_folder_type == Geary.SpecialFolderType.SPAM)
            return;

        show_images_email (false);
    }
}
