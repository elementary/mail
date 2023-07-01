/*
* Copyright (c) 2017-2023 elementary, Inc. (https://elementary.io)
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
* along with this program. If not, see <http://www.gnu.org/licenses/>
*
* Authored by: Leonhard Kargl <leo.kargl@proton.me>
*/

public class Mail.SignatureDialog : Hdy.ApplicationWindow {
    private const string ACTION_GROUP_PREFIX = "win";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    private Gtk.ListBox signature_list;
    private Gtk.Entry title_entry;
    private Mail.WebView web_view;
    private Signature? current_signature;
    private Signature? last_deleted_signature;
    private Granite.Widgets.Toast toast;
    private bool selection_change_ongoing = false;

    construct {
        var start_header = new Hdy.HeaderBar () {
            show_close_button = true
        };
        start_header.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        start_header.get_style_context ().add_class ("default-decoration");

        var placeholder = new Gtk.Label (_("No Signatures added yet"));
        placeholder.show_all ();

        signature_list = new Gtk.ListBox () {
            vexpand = true,
            selection_mode = BROWSE
        };
        signature_list.set_filter_func ((Gtk.ListBoxFilterFunc)filter_func);
        signature_list.set_placeholder (placeholder);

        var add_box = new Gtk.Box (HORIZONTAL, 0);
        add_box.add (new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.SMALL_TOOLBAR));
        add_box.add (new Gtk.Label (_("Create Signature")));

        var add_button = new Gtk.Button () {
            child = add_box
        };
        add_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var start_actionbar = new Gtk.ActionBar ();
        start_actionbar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        start_actionbar.pack_start (add_button);

        var start_box = new Gtk.Box (VERTICAL, 0) {
            width_request = 200
        };
        start_box.get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);
        start_box.add (start_header);
        start_box.add (signature_list);
        start_box.add (start_actionbar);

        var title = new Granite.HeaderLabel (_("Title")) {
            margin_start = 9
        };

        var end_header = new Hdy.HeaderBar () {
            show_close_button = true
        };
        end_header.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        end_header.get_style_context ().add_class ("default-decoration");
        end_header.pack_start (title);

        title_entry = new Gtk.Entry () {
            margin_top = 2, //Work around a styling issue
            margin_start = 12,
            margin_end = 12,
            placeholder_text = _("For example “Work” or “Personal”"),
            sensitive = false
        };

        web_view = new Mail.WebView () {
            editable = true,
            sensitive = false
        };

        try {
            var template = resources_lookup_data ("/io/elementary/mail/blank-editor-template.html", ResourceLookupFlags.NONE);
            web_view.load_html ((string)template.get_data ());
        } catch (Error e) {
            warning ("Failed to load blank editor template: %s", e.message);
        }

        var frame = new Gtk.Frame (null) {
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 12,
            child = web_view
        };

        var delete_button = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.SMALL_TOOLBAR) {
            tooltip_text = _("Delete"),
            sensitive = false
        };
        delete_button.get_style_context ().add_class (Gtk.STYLE_CLASS_ERROR);

        var default_menu = new Menu ();

        var default_menubutton = new Gtk.MenuButton () {
            menu_model = default_menu,
            label = _("Set Default For…"),
            use_popover = false,
            direction = UP,
            sensitive = false
        };

        var end_actionbar = new Gtk.ActionBar ();
        end_actionbar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        end_actionbar.pack_start (delete_button);
        end_actionbar.pack_end (default_menubutton);

        var content_box = new Gtk.Box (VERTICAL, 0);
        content_box.add (title_entry);
        content_box.add (new Granite.HeaderLabel (_("Signature")) { margin_start = 12 });
        content_box.add (frame);
        content_box.add (end_actionbar);

        var end_box = new Gtk.Box (VERTICAL, 0);
        end_box.get_style_context ().add_class (Gtk.STYLE_CLASS_VIEW);
        end_box.add (end_header);
        end_box.add (content_box);

        var action_sizegroup = new Gtk.SizeGroup (VERTICAL);
        action_sizegroup.add_widget (start_actionbar);
        action_sizegroup.add_widget (end_actionbar);

        var main_box = new Gtk.Box (HORIZONTAL, 0);
        main_box.add (start_box);
        main_box.add (end_box);

        toast = new Granite.Widgets.Toast ("");
        toast.set_default_action (_("Undo"));

        var overlay = new Gtk.Overlay () {
            child = main_box
        };
        overlay.add_overlay (toast);

        var header_group = new Hdy.HeaderGroup ();
        header_group.add_header_bar (start_header);
        header_group.add_header_bar (end_header);

        unowned var application = (Application)GLib.Application.get_default ();
        MainWindow? main_window = null;
        foreach (unowned var window in application.get_windows ()) {
            if (window is MainWindow) {
                main_window = (MainWindow) window;
                break;
            }
        }

        if (main_window != null) {
            transient_for = main_window;
        }

        default_height = 300;
        default_width = 500;
        add (overlay);
        show_all ();
        present ();

        load_signatures.begin ();

        populate_default_menu (default_menu);

        action_state_changed.connect (update_default_signature);

        add_button.clicked.connect (() => create_new_signature.begin ());

        title_entry.changed.connect (() => {
            if (!selection_change_ongoing && signature_list.get_selected_row () != null) {
                ((Signature)signature_list.get_selected_row ()).title = title_entry.text;
            }
        });

        delete_button.clicked.connect (delete_selected_signature);

        toast.default_action.connect (() => {
            last_deleted_signature.undo_delete ();
            signature_list.invalidate_filter ();
        });

        signature_list.row_selected.connect ((row) => {
            title_entry.sensitive = row != null;
            web_view.sensitive = row != null;
            delete_button.sensitive = row != null;
            default_menubutton.sensitive = row != null;

            set_selected_signature.begin ((Signature)row);
        });

        delete_event.connect (() => {
            finish.begin (() => {
                destroy ();
            });
            return Gdk.EVENT_STOP;
        });
    }

    private static bool filter_func (Signature signature) {
        return !signature.is_deleted;
    }

    private async void finish () {
        /* Save the current open signature */
        yield set_selected_signature (null);

        foreach (var child in signature_list.get_children ()) {
            var signature = (Signature)child;
            if (!signature.is_visible ()) {
                yield signature.finish_delete_signature ();
            }
        }
    }

    private async void set_selected_signature (Signature? signature) {
        if (current_signature != null) {
            current_signature.content = yield web_view.get_body_html ();
            yield current_signature.save ();
        }

        current_signature = signature;

        if (signature == null) {
            title_entry.text = "";
            web_view.set_content_of_element ("body", "");

            return;
        }

        selection_change_ongoing = true;

        title_entry.text = signature.title;
        web_view.set_content_of_element ("body", signature.content);

        unowned var session = Backend.Session.get_default ();
        foreach (var account in session.get_accounts ()) {
            var identity_source = session.get_identity_source_for_account_uid (account.service.uid);
            unowned var identity_extension = (E.SourceMailIdentity)identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_IDENTITY);
            if (identity_extension.signature_uid == signature.uid) {
                change_action_state (account.service.uid, true);
            } else {
                change_action_state (account.service.uid, false);
            }
        }

        selection_change_ongoing = false;
    }

    private async void load_signatures () {
        foreach (var signature_source in Mail.Backend.Session.get_default ().get_all_signature_sources ()) {
            var signature = yield new Signature (signature_source);
            signature_list.add (signature);
        }

        signature_list.select_row (signature_list.get_row_at_index (0));
    }

    private void populate_default_menu (Menu menu) {
        unowned var session = Backend.Session.get_default ();
        foreach (var account in session.get_accounts ()) {
            var action = new SimpleAction.stateful (account.service.uid, null, false);
            add_action (action);
            menu.append (account.service.display_name, ACTION_PREFIX + account.service.uid);
        }
    }

    private void update_default_signature (string account_uid, Variant? set_default) {
        if (selection_change_ongoing || current_signature == null) {
            return;
        }

        unowned var session = Backend.Session.get_default ();
        if (set_default.get_boolean ()) {
            session.set_signature_uid_for_account_uid.begin (account_uid, current_signature.uid);
        } else {
            session.set_signature_uid_for_account_uid.begin (account_uid, "none");
        }
    }

    private async void create_new_signature () {
        var new_signature_source = yield Mail.Backend.Session.get_default ().create_new_signature ();

        if (new_signature_source == null) {
            return;
        }

        var new_signature = yield new Signature (new_signature_source);
        signature_list.add (new_signature);
        signature_list.select_row (new_signature);
    }

    private void delete_selected_signature () {
        var signature = (Signature)signature_list.get_selected_row ();
        var index = signature.get_index () + 1;
        last_deleted_signature = signature;

        signature.delete_signature ();

        signature_list.invalidate_filter ();
        signature_list.select_row (signature_list.get_row_at_index (index));

        toast.title = _("'%s' deleted".printf (signature.title));
        toast.send_notification ();
    }
}
