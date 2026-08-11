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

public class Mail.AliasDialog : Granite.Dialog {
    public string account_uid { get; construct; }

    private HashTable<string, string?> aliases;
    private ListStore alias_list;
    private Gtk.ListBox list_box;
    private Granite.Toast toast;
    private string primary_name;

    public AliasDialog (string account_uid) {
        Object (account_uid: account_uid);
    }

    construct {
        var placeholder_title = new Gtk.Label (_("No Aliases")) {
            xalign = 0
        };

        var placeholder_description = new Gtk.Label (_("Add aliases using the button in the toolbar below")) {
            wrap = true,
            xalign = 0
        };
        placeholder_description.add_css_class (Granite.CssClass.DIM);
        placeholder_description.add_css_class (Granite.CssClass.SMALL);

        var placeholder = new Gtk.Box (VERTICAL, 0) {
            margin_start = 12,
            margin_end = 12,
            halign = CENTER,
            valign = CENTER
        };
        placeholder.append (placeholder_title);
        placeholder.append (placeholder_description);

        alias_list = new ListStore (typeof (Alias));

        list_box = new Gtk.ListBox () {
            vexpand = true,
            hexpand = true,
            selection_mode = NONE
        };
        list_box.bind_model (alias_list, (obj) => (Alias) obj);
        list_box.set_filter_func ((Gtk.ListBoxFilterFunc) filter_func);
        list_box.set_placeholder (placeholder);

        var scrolled_window = new Gtk.ScrolledWindow () {
            child = list_box,
            hscrollbar_policy = NEVER
        };

        var add_button_label = new Gtk.Label (_("Add Alias…"));

        var add_box = new Gtk.Box (HORIZONTAL, 0);
        add_box.append (new Gtk.Image.from_icon_name ("list_box-add-symbolic"));
        add_box.append (add_button_label);

        var add_button = new Gtk.Button () {
            child = add_box,
            margin_top = 3,
            margin_bottom = 3
        };
        add_button.add_css_class ("image-button");
        add_button_label.mnemonic_widget = add_button;

        var actionbar = new Gtk.ActionBar ();
        actionbar.add_css_class (Granite.STYLE_CLASS_FLAT);
        actionbar.pack_start (add_button);

        var content_box = new Gtk.Box (VERTICAL, 0);
        content_box.append (scrolled_window);
        content_box.append (actionbar);

        var frame = new Gtk.Frame (null) {
            margin_start = 12,
            margin_end = 12,
            child = content_box
        };

        toast = new Granite.Toast ("");
        toast.set_default_action (_("Undo"));

        var overlay = new Gtk.Overlay () {
            child = frame
        };
        overlay.add_overlay (toast);

        title = _("Aliases");
        default_height = 300;
        default_width = 500;
        get_content_area ().append (overlay);
        this.add_button (_("Close"), Gtk.ResponseType.CLOSE);

        var identity_source = Backend.Session.get_default ().get_identity_source_for_account_uid (account_uid);
        var extension = (E.SourceMailIdentity) identity_source.get_extension (E.SOURCE_EXTENSION_MAIL_IDENTITY);
        primary_name = extension.name;

        populate_list_box ();

        add_button.clicked.connect (() => create_new_alias ());

        toast.default_action.connect (() => {
            for (int i = 0; i < alias_list.n_items; i++) {
                ((Alias) alias_list.get_item (i)).undo_delete ();
            }

            list_box.invalidate_filter ();
        });

        response.connect (destroy);

        close_request.connect (() => {
            for (int i = 0; i < alias_list.n_items; i++) {
                var alias = (Alias) alias_list.get_item (i);
                if (alias.is_deleted) {
                    alias_list.remove (i);
                    aliases.remove (alias.address);
                }
            }

            write_aliases ();

            return Gdk.EVENT_PROPAGATE;
        });
    }

    private static bool filter_func (Alias alias) {
        return !alias.is_deleted;
    }

    private void populate_list_box () {
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
            list_box.invalidate_filter ();

            toast.title = _("'%s' deleted").printf (alias.alias_name != "" ? alias.alias_name : alias.address);
            toast.send_notification ();
        });

        alias.finish_delete.connect (() => {
            uint pos = -1;
            if (alias_list.find (alias, out pos)) {
                alias_list.remove (pos);
            };

            aliases.remove (alias.address);
            write_aliases ();
        });

        alias_list.append (alias);
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
