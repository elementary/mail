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

public class Mail.Utils {

    public delegate bool AcceptAddress (string address);
    public static string get_reply_addresses (string raw_addresses, AcceptAddress should_add) {
        var own_addresses = Backend.Session.get_default ().get_own_addresses ();
        var output = "";
        var added_addresses = new Gee.ArrayList<string> ();

        var addresses = new Camel.InternetAddress ();
        addresses.decode (raw_addresses);
        addresses.ref ();
        for (int i = 0; i < addresses.length (); i++) {
            string? address;
            addresses.@get (i, null, out address);
            if (address == null) {
                continue;
            }

            address = address.casefold ();
            var is_own_address = false;
            foreach (var own_address in own_addresses) {
                if (address.contains (own_address)) {
                    is_own_address = true;
                    break;
                }
            }

            if (!is_own_address && should_add (address) && !added_addresses.contains (address)) {
                added_addresses.add (address);
                if (output.length > 0) {
                    output += ", %s".printf (address);
                } else {
                    output += address;
                }
            }
        }

        return output;
    }

    public static string escape_html_tags (string input) {
        return input.replace ("<", "&lt;").replace (">", "&gt;");
    }

    //FIXME: Remove this util when Granite 5.2 is released.
    private static string accel_to_string (string accel) {
        uint accel_key;
        Gdk.ModifierType accel_mods;
        Gtk.accelerator_parse (accel, out accel_key, out accel_mods);

        string[] arr = {};
        if (Gdk.ModifierType.SUPER_MASK in accel_mods) {
            arr += "⌘";
        }

        if (Gdk.ModifierType.SHIFT_MASK in accel_mods) {
            arr += _("Shift");
        }

        if (Gdk.ModifierType.CONTROL_MASK in accel_mods) {
            arr += _("Ctrl");
        }

        if (Gdk.ModifierType.MOD1_MASK in accel_mods) {
            arr += _("Alt");
        }

        switch (accel_key) {
            case Gdk.Key.Up:
                arr += "↑";
                break;
            case Gdk.Key.Down:
                arr += "↓";
                break;
            case Gdk.Key.Left:
                arr += "←";
                break;
            case Gdk.Key.Right:
                arr += "→";
                break;
            default:
                arr += Gtk.accelerator_get_label (accel_key, 0);
                break;
        }

        return string.joinv (" + ", arr);
    }

    //FIXME: Remove this util when Granite 5.2 is released.
    public static string markup_accel_tooltip (string[] accels, string? description = null) {
        for (int i = 0; i < accels.length; i++) {
            accels[i] = accel_to_string (accels[i]); 
        }

        ///TRANSLATORS: This is a delimiter that separates two keyboard shortcut labels like "⌘ + →, Control + A"
        var accel_label = string.joinv (_(", "), accels);

        var markup = """<span weight="600" size="smaller" alpha="75%">%s</span>""".printf (accel_label);

        if (description != null && description != "") {
            markup = string.join ("\n", description, markup);
        }

        return markup;
    }
}
