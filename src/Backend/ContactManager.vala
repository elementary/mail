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

public class Mail.ContactManager : GLib.Object {
    private static ContactManager instance;
    public static unowned ContactManager get_default () {
        if (instance == null) {
            instance = new ContactManager ();
        }

        return instance;
    }

    public Gtk.ListStore list_store { get; private set; }

    private Gee.TreeSet<string> email_addresses;
    private Folks.IndividualAggregator individual_aggregator;

    construct {
        email_addresses = new Gee.TreeSet<string> ();
        list_store = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (string));
        list_store.set_default_sort_func (list_store_sort_func);
        list_store.set_sort_column_id (2, Gtk.SortType.ASCENDING);
        individual_aggregator = Folks.IndividualAggregator.dup ();
        load_contact.begin ();
    }

    public void setup_entry (Gtk.Entry entry) {
        var name_cell = new Gtk.CellRendererText ();
        var completion = new Gtk.EntryCompletion ();
        completion.set_model (list_store);
        completion.set_match_func (entry_completion);
        completion.pack_start (name_cell, true);
        completion.set_cell_data_func (name_cell, layout_text);
        completion.match_selected.connect ((model, iter) => {
            string name, email;
            list_store.get (iter, 0, out name, 1, out email);
            var parts = entry.text.split (",");
            var text = "";
            for (uint i = 0; i < parts.length - 1; i++) {
                text = "%s%s, ".printf (text, parts[i]);
            }

            if (name != email) {
                text += "%s <%s>, ".printf (name, email);
            } else {
                text += "%s, ".printf (email);
            }
            entry.text = text;
            GLib.Signal.emit_by_name (entry, "move-cursor", Gtk.MovementStep.VISUAL_POSITIONS, text.char_count () - entry.cursor_position, false);
            return true;
        });
        entry.set_completion (completion);
    }

    public async void remember_mail_address (string address, string? name) {
        name = name ?? address;

        if (!Granite.Services.System.history_is_enabled ()) {
            debug ("History disabled, don't remember email addresses.");
            return;
        }

        if (address in email_addresses) {
            debug ("Mail address already in addressbook.");
            return;
        }

        if (individual_aggregator.primary_store == null) {
            MainWindow.send_error_message (
                _("Couldn't add “%s” to addressbook").printf (name),
                _("No addressbook available."),
                "avatar-default"
            );
            return;
        } else if (!individual_aggregator.primary_store.is_prepared) {
            ulong handler = 0;
            handler = individual_aggregator.primary_store.notify["is-prepared"].connect (() => {
                remember_mail_address.begin (address, name);
                individual_aggregator.primary_store.disconnect (handler);
            });
            return;
        }


        var details = new HashTable<string, Value?> (str_hash, str_equal);

        var address_set = new Gee.HashSet<Folks.EmailFieldDetails> ();
        address_set.add (new Folks.EmailFieldDetails (address));
        var address_val = Value (typeof (Gee.Set));
        address_val.set_object (address_set);

        var name_val = Value (typeof (string));
        name_val.set_string (name);

        details[Folks.PersonaStore.detail_key (EMAIL_ADDRESSES)] = address_val;
        details[Folks.PersonaStore.detail_key (FULL_NAME)] = name_val;

        try {
            debug ("Remember '%s' with email address '%s'.", name, address);
            yield individual_aggregator.add_persona_from_details (null, individual_aggregator.primary_store, details);
        } catch (Error e) {
            warning ("Failed to add mail address: %s", e.message);
            MainWindow.send_error_message (
                _("Couldn't add “%s” to addressbook").printf (name),
                _("Operation failed."),
                "avatar-default",
                e.message
            );
        }
    }

    private string current_key = null;
    private string real_key = null;
    private bool entry_completion (Gtk.EntryCompletion completion, string key, Gtk.TreeIter iter) {
        if (current_key != key) {
            current_key = key;
            var parts = key.split (",");
            real_key = parts[parts.length - 1].strip ();
        }

        if (real_key == "") {
            return false;
        }

        string name, address;
        list_store.get (iter, 0, out name, 1, out address);
        if (address == null || address in key) {
            return false;
        }

        if (name != null) {
            return real_key in name.normalize ().casefold ();
        }

        return false;
    }

    private void layout_text (Gtk.CellLayout cell_layout, Gtk.CellRenderer cell, Gtk.TreeModel tree_model, Gtk.TreeIter iter) {
        string name, address;
        tree_model.get (iter, 0, out name, 1, out address);
        address = GLib.Markup.escape_text (address).replace (real_key, "<b>%s</b>".printf (GLib.Markup.escape_text (real_key)));
        name = GLib.Markup.escape_text (name).replace (real_key, "<b>%s</b>".printf (GLib.Markup.escape_text (real_key)));
        string new_text;
        if (name == address) {
            new_text = address;
        } else {
            new_text = "%s <span size=\"smaller\">%s</span>".printf (name, address);
        }

        ((Gtk.CellRendererText) cell).markup = new_text;
    }

    private async void load_contact () {
        individual_aggregator.individuals_changed_detailed.connect ((changes) => {
            foreach (var individual in changes.get (null)) {
                add_individual (individual);
            }
        });

        foreach (var individual in individual_aggregator.individuals.values) {
            add_individual (individual);
        }

        try {
            yield individual_aggregator.prepare ();
        } catch (Error e) {
            critical (e.message);
        }
    }

    private void add_individual (Folks.Individual individual) {
        string individual_name = individual.display_name;
        string individual_collate = individual_name.collate_key ();
        foreach (var email_object in individual.email_addresses) {
            string email = email_object.value;
            if (!(email in email_addresses)) {
                email_addresses.add (email);
            }
            Gtk.TreeIter iter;
            list_store.append (out iter);
            string collation_key;
            if (individual_name == email) {
                collation_key = email.collate_key ();
            } else {
                collation_key = individual_collate + email.collate_key ();
            }

            list_store.set (iter, 0, individual_name, 1, email, 2, collation_key);
        }
    }

    private static int list_store_sort_func (Gtk.TreeModel model, Gtk.TreeIter a, Gtk.TreeIter b) {
        string key_a, key_b;
        model.get (a, 2, out key_a);
        model.get (b, 2, out key_b);

        return strcmp (key_a, key_b);
    }
}
