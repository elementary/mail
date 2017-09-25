/*
* Copyright (c) 2016 elementary LLC (http://launchpad.net/pantheon-mail
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA.
*
* Authored by: Daniel Foré <daniel@elementary.io>
*/

public class AccountDialogRemoveConfirmPane : AccountDialogPane {
    private Geary.AccountInformation? account = null;
    private Gtk.Label account_nickname_label;
    private Gtk.Label email_address_label;
    public Gtk.Button cancel_button;

    public signal void remove_account (Geary.AccountInformation? account);

    public AccountDialogRemoveConfirmPane (Gtk.Stack stack) {
        base (stack);

        var remove_image = new Gtk.Image.from_icon_name ("dialog-warning", Gtk.IconSize.DIALOG);
        remove_image.valign = Gtk.Align.START;

        var primary_label = new Gtk.Label (_("Are you sure you want to remove this account?"));
        primary_label.get_style_context ().add_class ("primary");
        primary_label.max_width_chars = 60;
        primary_label.wrap = true;
        primary_label.xalign = 0;

        var secondary_label = new Gtk.Label (_("All email associated with this account will be removed from your computer. This will not affect email on the server."));
        secondary_label.max_width_chars = 60;
        secondary_label.wrap = true;
        secondary_label.xalign = 0;

        var account_nickname = new Gtk.Label (_("Nickname:"));
        account_nickname.halign = Gtk.Align.END;
        account_nickname_label = new Gtk.Label ("");
        account_nickname_label.use_markup = true;
        account_nickname_label.xalign = 0;

        var email_address = new Gtk.Label (_("Email Address:"));
        email_address.halign = Gtk.Align.END;
        email_address_label = new Gtk.Label ("");
        email_address_label.use_markup = true;
        email_address_label.xalign = 0;

        cancel_button = new Gtk.Button.with_label (_("Cancel"));

        var remove_button = new Gtk.Button.with_label (_("Remove Account"));
        remove_button.get_style_context ().add_class ("destructive-action");

        var button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        button_box.set_layout (Gtk.ButtonBoxStyle.END);
        button_box.set_spacing (6);
        button_box.margin_top = 18;
        button_box.valign = Gtk.Align.END;
        button_box.vexpand = true;
        button_box.add (cancel_button);
        button_box.add (remove_button);

        var layout = new Gtk.Grid ();
        layout.margin = 6;
        layout.margin_top = 0;
        layout.column_spacing = 12;
        layout.row_spacing = 6;
        layout.attach (remove_image, 0, 0, 1, 4);
        layout.attach (primary_label, 1, 0, 2, 1);
        layout.attach (secondary_label, 1, 1, 2, 1);
        layout.attach (account_nickname, 1, 2, 1, 1);
        layout.attach (account_nickname_label, 2, 2, 1, 1);
        layout.attach (email_address, 1, 3, 1, 1);
        layout.attach (email_address_label, 2, 3, 1, 1);
        layout.attach (button_box, 1, 4, 2, 1);

        add (layout);

        remove_button.clicked.connect (() => {
            remove_account (account);
        });
    }

    public void set_account (Geary.AccountInformation account_name) {
        account = account_name;
        account_nickname_label.label = "<b>%s</b>".printf (account.nickname);
        email_address_label.label = "<b>%s</b>".printf (account.email);
    }
}

