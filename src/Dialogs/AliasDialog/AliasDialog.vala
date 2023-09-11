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

public class Mail.AliasDialog : Hdy.ApplicationWindow {
    private const string ACTION_GROUP_PREFIX = "win";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";

    public string account_uid { get; construct; }

    private HashTable<string, string?> aliases;
    private Gtk.ListBox list;
    private Granite.Widgets.Toast toast;
    private string primary_name;
    private bool selection_change_ongoing = false;

    public AliasDialog (string account_uid) {
        Object (account_uid: account_uid);
    }

    construct {
        var header = new Hdy.HeaderBar () {
            show_close_button = true
        };
        header.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        header.get_style_context ().add_class ("default-decoration");

        var placeholder_title = new Gtk.Label (_("No Aliases")) {
            xalign = 0
        };

        var placeholder_description = new Gtk.Label (_("Add signatures using the button in the toolbar below")) {
            wrap = true,
            xalign = 0
        };
        placeholder_description.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        placeholder_description.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);

        var placeholder = new Gtk.Box (VERTICAL, 0) {
            margin_start = 12,
            margin_end = 12
        };
        placeholder.add (placeholder_title);
        placeholder.add (placeholder_description);
        placeholder.show_all ();

        list = new Gtk.ListBox () {
            vexpand = true,
            hexpand = true,
            selection_mode = NONE
        };
        list.set_filter_func ((Gtk.ListBoxFilterFunc) filter_func);
        list.set_placeholder (placeholder);

        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            child = list,
            hscrollbar_policy = NEVER
        };

        var add_box = new Gtk.Box (HORIZONTAL, 0);
        add_box.add (new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.SMALL_TOOLBAR));
        add_box.add (new Gtk.Label (_("Add Alias")));

        var add_button = new Gtk.Button () {
            child = add_box,
            margin_top = 2,
            margin_bottom = 2
        };
        add_button.get_style_context ().add_class ("image-button");

        var actionbar = new Gtk.ActionBar ();
        actionbar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
        actionbar.pack_start (add_button);

        var content_box = new Gtk.Box (VERTICAL, 0);
        content_box.add (scrolled_window);
        content_box.add (actionbar);

        var frame = new Gtk.Frame (null) {
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 12,
            child = content_box
        };

        var box = new Gtk.Box (VERTICAL, 0);
        box.add (header);
        box.add (frame);

        toast = new Granite.Widgets.Toast ("");
        toast.set_default_action (_("Undo"));

        var overlay = new Gtk.Overlay () {
            child = box
        };
        overlay.add_overlay (toast);

        default_height = 300;
        default_width = 500;
        add (overlay);
        show_all ();
        present ();

        var identity_source = Backend.Session.get_default ().get_identity_source_for_account_uid (account_uid);
        var identity_extension = (E.SourceMailIdentity) identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_IDENTITY);
        primary_name = identity_extension.name;

        populate_list ();

        add_button.clicked.connect (() => create_new_alias ());

        toast.default_action.connect (() => {
            foreach (var child in list.get_children ()) {
                if (child is Alias) {
                    ((Alias) child).undo_delete ();
                }
            }

            list.invalidate_filter ();
        });

        delete_event.connect (() => {
            foreach (var child in list.get_children ()) {
                if (child is Alias && ((Alias) child).is_deleted) {
                    aliases.remove (((Alias) child).address);
                }
            }

            write_aliases ();

            return Gdk.EVENT_PROPAGATE;
        });
    }

    private static bool filter_func (Alias alias) {
        return !alias.is_deleted;
    }

    // private async void finish () {
    //     /* Save the current open signature */
    //     yield set_selected_signature (null);

    //     foreach (var child in signature_list.get_children ()) {
    //         var signature = (Signature)child;
    //         if (signature.is_deleted) {
    //             yield signature.finish_delete_signature ();
    //         }
    //     }
    // }

    // private async void set_selected_signature (Signature? signature) {
    //     if (current_signature != null) {
    //         current_signature.content = yield web_view.get_body_html ();
    //         yield current_signature.save ();
    //     }

    //     current_signature = signature;

    //     if (signature == null) {
    //         title_entry.text = "";
    //         web_view.set_content_of_element ("body", "");

    //         return;
    //     }

    //     selection_change_ongoing = true;

    //     title_entry.text = signature.title;
    //     web_view.set_content_of_element ("body", signature.content);

    //     unowned var session = Backend.Session.get_default ();
    //     foreach (var account in session.get_accounts ()) {
    //         var identity_source = session.get_identity_source_for_account_uid (account.service.uid);
    //         unowned var identity_extension = (E.SourceMailIdentity)identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_IDENTITY);
    //         if (identity_extension.signature_uid == signature.uid) {
    //             change_action_state (account.service.uid, true);
    //         } else {
    //             change_action_state (account.service.uid, false);
    //         }
    //     }

    //     selection_change_ongoing = false;
    // }

    private void populate_list () {
        aliases = Mail.Backend.Session.get_default ().get_aliases_for_account_uid (account_uid);

        if (aliases == null) {
            aliases = new HashTable<string, string> (str_hash, str_equal);
        }

        foreach (var address in aliases.get_keys ()) {
            add_alias (address, aliases[address]);
        }
    }

    private void create_new_alias () {
        add_alias (null, primary_name);
    }

    private void add_alias (string? address, string? name) {
        Alias alias;
        if (address == null) {
            alias = new Alias.create_new (name);
        } else {
            alias = new Alias (address, name ?? "");
        }

        alias.save.connect ((old_address) => {
            if (old_address != alias.address) {
                aliases.remove (old_address);
            }

            aliases[alias.address] = alias.alias_name;
            write_aliases ();
        });

        alias.start_delete.connect (() => {
            list.invalidate_filter ();

            toast.title = _("'%s' deleted").printf (alias.alias_name.strip () != "" ? alias.alias_name : alias.address);
            toast.send_notification ();
        });

        alias.finish_delete.connect (() => {
            list.remove (alias);
            aliases.remove (alias.address);
            write_aliases ();
        });

        list.add (alias);
    }

    private void write_aliases () {
        var encoded_aliases = new Camel.InternetAddress ();

        aliases.foreach ((key, val) => {
            encoded_aliases.add (val ?? "", key);
        });

        Backend.Session.get_default ().set_aliases_for_account_uid.begin (account_uid, encoded_aliases.encode ());
    }

    // private void populate_default_menu (Menu menu) {
    //     unowned var session = Backend.Session.get_default ();
    //     foreach (var account in session.get_accounts ()) {
    //         var action = new SimpleAction.stateful (account.service.uid, null, false);
    //         add_action (action);
    //         menu.append (account.service.display_name, ACTION_PREFIX + account.service.uid);
    //     }
    // }

    // private void update_default_signature (string account_uid, Variant? set_default) {
    //     if (selection_change_ongoing || current_signature == null) {
    //         return;
    //     }

    //     unowned var session = Backend.Session.get_default ();
    //     if (set_default.get_boolean ()) {
    //         session.set_signature_uid_for_account_uid.begin (account_uid, current_signature.uid);
    //     } else {
    //         session.set_signature_uid_for_account_uid.begin (account_uid, "none");
    //     }
    // }

    // private async void create_new_signature () {
    //     var new_signature_source = yield Mail.Backend.Session.get_default ().create_new_signature ();

    //     if (new_signature_source == null) {
    //         return;
    //     }

    //     var new_signature = yield new Signature (new_signature_source);
    //     signature_list.add (new_signature);
    //     signature_list.select_row (new_signature);
    // }

    // private void delete_selected_signature () {
    //     var signature = (Signature)signature_list.get_selected_row ();
    //     var index = signature.get_index () + 1;
    //     last_deleted_signature = signature;

    //     signature.delete_signature ();

    //     signature_list.invalidate_filter ();
    //     signature_list.select_row (signature_list.get_row_at_index (index));

    //     toast.title = _("'%s' deleted").printf (signature.title);
    //     toast.send_notification ();
    // }
}
