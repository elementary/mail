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
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*
* Authored by: Daniel Foré <daniel@elementary.io>
*/

public class PasswordDialog : Gtk.Dialog {
    private Gtk.Button authenticate_button;
    private Gtk.CheckButton checkbox; 
    private Gtk.Entry password_entry;
    
    public string password { get; private set; default = ""; }
    public bool remember_password { get; private set; }

    public PasswordDialog (Gtk.Window? parent, bool smtp, Geary.AccountInformation account_information, Geary.ServiceFlag password_flags) {
        border_width = 6;
        deletable = false;
        resizable = false;
        transient_for = parent;

        var password_image = new Gtk.Image.from_icon_name ("dialog-password", Gtk.IconSize.DIALOG);
        password_image.valign = Gtk.Align.START;

        var primary_label = new Gtk.Label (_("Mail requires your email password to continue"));
        primary_label.get_style_context ().add_class ("primary");
        primary_label.max_width_chars = 60;
        primary_label.wrap = true;
        primary_label.xalign = 0;

        var username_label = new Gtk.Label (_("Username:"));
        username_label.halign = Gtk.Align.END;

        var username_widget = new Gtk.Label ("");
        username_widget.hexpand = true;
        username_widget.xalign = 0;

        var password_label = new Gtk.Label (_("Password:"));
        password_label.halign = Gtk.Align.END;

        var smtp_label = new Gtk.Label (_("SMTP Credentials:"));
        smtp_label.no_show_all = true;

        password_entry = new Gtk.Entry ();
        password_entry.set_input_purpose (Gtk.InputPurpose.PASSWORD);
        password_entry.visibility = false;

        checkbox = new Gtk.CheckButton.with_label (_("Remember password"));
        checkbox.margin_top = 6;
        checkbox.active = (smtp ? account_information.smtp_remember_password : account_information.imap_remember_password);

        if (smtp) {
            username_widget.label = account_information.smtp_credentials.user;
            password_entry.text = account_information.smtp_credentials.pass;
            smtp_label.show ();
        } else {
            username_widget.label = account_information.imap_credentials.user;
            password_entry.text = account_information.imap_credentials.pass;
        }

        authenticate_button = new Gtk.Button.with_label (_("Authenticate"));
        authenticate_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        authenticate_button.sensitive = false;

        var layout = new Gtk.Grid ();
        layout.margin = 6;
        layout.margin_top = 0;
        layout.column_spacing = 12;
        layout.row_spacing = 6;
        layout.attach (password_image, 0, 0, 1, 4);
        layout.attach (primary_label, 1, 0, 2, 1);
        layout.attach (smtp_label, 1, 1, 2, 1);
        layout.attach (username_label, 1, 2, 1, 1);
        layout.attach (username_widget, 2, 2, 1, 1);
        layout.attach (password_label, 1, 3, 1, 1);
        layout.attach (password_entry, 2, 3, 1, 1);
        layout.attach (checkbox, 2, 4, 1, 1);

        var content = get_content_area () as Gtk.Box;
        content.add (layout);

        add_button (_("Cancel"), Gtk.ResponseType.CLOSE);
        add_action_widget (authenticate_button, Gtk.ResponseType.OK);
        show_all ();

        response.connect (on_response);
        password_entry.changed.connect (refresh_ok_button_sensitivity);
        password_entry.activate.connect (() => {
            authenticate_button.activate ();
        });
    }

    private void refresh_ok_button_sensitivity () {
        authenticate_button.sensitive = !Geary.String.is_empty_or_whitespace (password_entry.get_text ());
    }

    private void on_response (Gtk.Dialog source, int response_id) {
        switch (response_id) {
        case Gtk.ResponseType.OK:
            password = password_entry.get_text ();
            remember_password = checkbox.active;
            break;
        case Gtk.ResponseType.CLOSE:
            destroy ();
            break;
        }
    }
}
