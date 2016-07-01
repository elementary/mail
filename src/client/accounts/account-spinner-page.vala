/* Copyright 2013-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

// Shows a simple spinner and a message indicating the account is being validated.
public class AccountSpinnerPage : Gtk.Grid {
    public AccountSpinnerPage () {
        
    }

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        row_spacing = 12;
        margin = 12;
        var spinner = new Gtk.Spinner ();
        spinner.expand = true;
        spinner.halign = Gtk.Align.CENTER;
        spinner.valign = Gtk.Align.END;
        spinner.set_size_request (48, 48);
        var waiting_label = new Gtk.Label (_("Please wait while Mail validates your account."));
        waiting_label.expand = true;
        waiting_label.halign = Gtk.Align.CENTER;
        waiting_label.valign = Gtk.Align.START;
        add (spinner);
        add (waiting_label);
        spinner.start ();
    }
}

