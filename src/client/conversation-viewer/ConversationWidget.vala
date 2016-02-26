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

    Gtk.EventBox header;
    Gtk.Stack header_fields_stack;
    Gtk.Grid header_expanded_fields;
    Gtk.Revealer content_revealer;
    Gtk.Grid content_grid;

    Granite.Widgets.Avatar avatar;

    private const string BODY = """
    <html>
        <head>
            <title>Geary</title>
        </head>
        <body>
            <div id="message_container"></div>
            %s
        </body>
    </html>
    """;

    Gtk.Label user_name;
    Gtk.Label user_mail;
    Gtk.Label message_content;
    Gtk.Label datetime;
    Gtk.Button star_button;
    Gtk.ToggleButton menu_button;

    Geary.Email email;
    ConversationWebView conversation_webview;
    bool opened = false;
    public ConversationWidget (Geary.Email email) {
        this.email = email;

        // Populate the summary widgets
        var clock_format = GearyApplication.instance.config.clock_format;
        datetime.label = Date.pretty_print (email.date.value, clock_format);
        email.from.get_all ().foreach ((address) => {
            if (address.name != null) {
                user_name.label = "<b>%s</b>".printf (Markup.escape_text (address.name));
                user_mail.label = address.address;
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
            var value_label = new Gtk.Label (email.subject.value);
            value_label.hexpand = true;
            value_label.halign = Gtk.Align.START;
            value_label.wrap = true;
            header_expanded_fields.attach (title_label, 0, row_id, 1, 1);
            header_expanded_fields.attach (value_label, 1, row_id, 1, 1);
            row_id++;
        }

        if (email.date != null) {
            var title_label = new Gtk.Label (_("Date:"));
            title_label.halign = Gtk.Align.END;
            var value_label = new Gtk.Label (Date.pretty_print_verbose (email.date.value, clock_format));
            value_label.hexpand = true;
            value_label.halign = Gtk.Align.START;
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
                warning (uri);
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
    }

    construct {
        margin = 12;
        get_style_context ().add_class ("card");

        // Creating the Header
        var header_grid = new Gtk.Grid ();
        header_grid.margin = 6;
        header_grid.column_spacing = 6;
        header_grid.row_spacing = 6;

        header = new Gtk.EventBox ();
        header.events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        header.events |= Gdk.EventMask.KEY_PRESS_MASK;
        header.tooltip_text = _("Click to view the message");
        header.add (header_grid);

        avatar = new Granite.Widgets.Avatar.with_default_icon (48);
        avatar.valign = Gtk.Align.START;

        user_name = new Gtk.Label (null);
        user_name.halign = Gtk.Align.START;
        user_name.use_markup = true;

        user_mail = new Gtk.Label (null);
        user_mail.ellipsize = Pango.EllipsizeMode.END;
        user_mail.halign = Gtk.Align.START;
        user_mail.hexpand = true;

        message_content = new Gtk.Label (null);
        message_content.hexpand = true;
        message_content.ellipsize = Pango.EllipsizeMode.END;
        message_content.use_markup = true;
        message_content.halign = Gtk.Align.START;
        message_content.valign = Gtk.Align.START;
        message_content.single_line_mode = true;

        datetime = new Gtk.Label (null);
        datetime.halign = Gtk.Align.END;
        datetime.valign = Gtk.Align.END;

        var header_summary_fields = new Gtk.Grid ();
        header_summary_fields.column_spacing = 6;
        header_summary_fields.row_spacing = 6;
        header_summary_fields.margin_top = 6;
        header_summary_fields.attach (user_name, 0, 0, 1, 1);
        header_summary_fields.attach (user_mail, 1, 0, 1, 1);
        header_summary_fields.attach (datetime, 2, 0, 1, 1);
        header_summary_fields.attach (message_content, 0, 1, 3, 1);

        header_expanded_fields = new Gtk.Grid ();
        header_expanded_fields.column_spacing = 6;
        header_expanded_fields.row_spacing = 6;
        header_expanded_fields.margin_top = 6;
        header_expanded_fields.no_show_all = true;

        header_fields_stack = new Gtk.Stack ();
        header_fields_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        header_fields_stack.add_named (header_summary_fields, "summary");
        header_fields_stack.add_named (header_expanded_fields, "expanded");

        star_button = new Gtk.Button.from_icon_name ("non-starred-symbolic", Gtk.IconSize.MENU);
        star_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        star_button.margin_top = 6;
        star_button.valign = Gtk.Align.START;
        star_button.halign = Gtk.Align.END;

        menu_button = new Gtk.ToggleButton ();
        menu_button.image = new Gtk.Image.from_icon_name ("view-more-symbolic", Gtk.IconSize.MENU);
        menu_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        menu_button.margin_top = 6;
        menu_button.valign = Gtk.Align.START;
        menu_button.halign = Gtk.Align.END;

        header_grid.attach (avatar, 0, 0, 1, 1);
        header_grid.attach (header_fields_stack, 1, 0, 1, 1);
        header_grid.attach (star_button, 4, 0, 1, 1);
        header_grid.attach (menu_button, 5, 0, 1, 1);

        conversation_webview = new ConversationWebView ();
        conversation_webview.transparent = true;
        conversation_webview.expand = true;

        content_grid = new Gtk.Grid ();
        content_grid.margin = 6;
        content_grid.margin_top = 0;
        content_grid.orientation = Gtk.Orientation.VERTICAL;
        content_grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        content_grid.add (conversation_webview);

        content_revealer = new Gtk.Revealer ();
        content_revealer.no_show_all = true;
        content_revealer.set_reveal_child (false);
        content_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;
        content_revealer.add (content_grid);

        header.button_press_event.connect ((event) => header_button_press_event (event));
        header.key_press_event.connect ((event) => header_key_press_event (event));
        header.realize.connect (() => {
            var window = header.get_window ();
            window.cursor = new Gdk.Cursor.for_display (window.get_display (), Gdk.CursorType.HAND1);
        });

        var main_grid = new Gtk.Grid ();
        main_grid.orientation = Gtk.Orientation.VERTICAL;
        main_grid.add (header);
        main_grid.add (content_revealer);

        add (main_grid);
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
                    value += Geary.HTML.escape_markup (a.address);
                    value += " <b>%s</b>".printf (Geary.HTML.escape_markup (a.name));
                } else {
                    value += "<b>%s</b> ".printf (Geary.HTML.escape_markup (a.name));
                    value += Geary.HTML.escape_markup (a.address);
                }
            } else {
                value += Geary.HTML.escape_markup (a.address);
            }
            value += "</a>";

            if (++i < list.size)
                value += ", ";
        }

        var title_label = new Gtk.Label (title);
        title_label.halign = Gtk.Align.END;
        var value_label = new Gtk.Label (value);
        value_label.hexpand = true;
        value_label.ellipsize = Pango.EllipsizeMode.END;
        value_label.use_markup = true;
        value_label.halign = Gtk.Align.START;
        header_expanded_fields.attach (title_label, 0, index, 1, 1);
        header_expanded_fields.attach (value_label, 1, index, 1, 1);
    }

    private bool header_button_press_event (Gdk.EventButton event) {
        toggle_view ();
        return true;
    }

    private bool header_key_press_event (Gdk.EventKey event) {
        if (event.state == 0 && event.keyval == Gdk.Key.KP_Enter) {
            toggle_view ();
            return true;
        }

        return false;
    }

    private void toggle_view () {
        if (content_revealer.child_revealed) {
            content_revealer.no_show_all = true;
            header_expanded_fields.no_show_all = true;
            header_fields_stack.set_visible_child_name ("summary");
            header_expanded_fields.hide ();
            content_revealer.set_reveal_child (false);
            Timeout.add (content_revealer.transition_duration, () => {
                content_revealer.hide ();
                return GLib.Source.REMOVE;
            });

        } else {
            content_revealer.no_show_all = false;
            content_revealer.show_all ();
            header_expanded_fields.no_show_all = false;
            header_expanded_fields.show_all ();
            header_fields_stack.set_visible_child_name ("expanded");
            content_revealer.set_reveal_child (true);

            if (opened == false) {
                opened = true;
                if (email.body == null) {
                    email.notify["body"].connect (open_message);
                } else {
                    open_message ();
                }
            }
        }
    }

    private void open_message () {
        email.notify["body"].disconnect (open_message);
        try {
            var message = email.get_message ();
            var body_text = message.get_html_body (null);
            conversation_webview.load_string (BODY.printf (body_text), "text/html", "UTF8", "");
        } catch (Error err) {
            debug("Could not get message text. %s", err.message);
        }
    }
}
