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
    public string account_uid { get; construct; }

    private HashTable<string, string?> aliases;
    private Gtk.ListBox list;
    private Granite.Widgets.Toast toast;
    private string primary_name;

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

        var placeholder_description = new Gtk.Label (_("Add aliases using the button in the toolbar below")) {
            wrap = true,
            xalign = 0
        };
        placeholder_description.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        placeholder_description.get_style_context ().add_class (Granite.STYLE_CLASS_SMALL_LABEL);

        var placeholder = new Gtk.Box (VERTICAL, 0) {
            margin_start = 12,
            margin_end = 12,
            halign = CENTER,
            valign = CENTER
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
        add_box.add (new Gtk.Label (_("Add Alias…")));

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

        title = _("Aliases");
        default_height = 300;
        default_width = 500;
        add (overlay);
        show_all ();
        present ();

        var identity_source = Backend.Session.get_default ().get_identity_source_for_account_uid (account_uid);
        var extension = (E.SourceMailIdentity) identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_IDENTITY);
        primary_name = extension.name;

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
        add_alias ("", primary_name);
    }

    private void add_alias (string address, string? name) {
        var alias = new Alias (address, name ?? "");

        alias.save.connect ((old_address) => {
            if (old_address != alias.address) {
                aliases.remove (old_address);
            }

            aliases[alias.address] = alias.alias_name;
            write_aliases ();
        });

        alias.start_delete.connect (() => {
            list.invalidate_filter ();

            toast.title = _("'%s' deleted").printf (alias.alias_name != "" ? alias.alias_name : alias.address);
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

        var session = Backend.Session.get_default ();
        session.set_aliases_for_account_uid.begin (account_uid, encoded_aliases.encode () ?? "");
    }
}
