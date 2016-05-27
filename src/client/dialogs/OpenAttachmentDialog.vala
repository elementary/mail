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

public class OpenAttachmentDialog : Gtk.Dialog {
    private Gtk.CheckButton checkbox;

    public OpenAttachmentDialog (Gtk.Window parent, Geary.Attachment attachment) {
        border_width = 6;
        deletable = false;
        resizable = false;
        transient_for = parent;

        var warning_image = new Gtk.Image.from_icon_name ("dialog-warning", Gtk.IconSize.DIALOG);
        warning_image.valign = Gtk.Align.START;

        var primary_label = new Gtk.Label (_("<span weight='bold' size='larger'>Are you sure you want to open %s?</span>").printf(attachment.file.get_basename()));
        primary_label.max_width_chars = 60;
        primary_label.use_markup = true;
        primary_label.wrap = true;
        primary_label.xalign = 0;

        var secondary_label = new Gtk.Label (_("Attachments may cause damage to your system if opened. Only open files from trusted sources."));
        secondary_label.max_width_chars = 60;
        secondary_label.wrap = true;
        secondary_label.xalign = 0;

        checkbox = new Gtk.CheckButton.with_label (_("Don't ask me again"));
        checkbox.margin_top = 6;

        var open_button = new Gtk.Button.with_label (_("Open Anyway"));
        open_button.get_style_context ().add_class ("destructive-action");

        var layout = new Gtk.Grid ();
        layout.margin = 6;
        layout.margin_top = 0;
        layout.column_spacing = 12;
        layout.row_spacing = 6;
        layout.attach (warning_image, 0, 0, 1, 3);
        layout.attach (primary_label, 1, 0, 1, 1);
        layout.attach (secondary_label, 1, 1, 1, 1);
        layout.attach (checkbox, 1, 2, 1, 1);

        var content = get_content_area () as Gtk.Box;
        content.add (layout);

        add_button (_("Cancel"), Gtk.ResponseType.CLOSE);
        add_action_widget (open_button, Gtk.ResponseType.OK);
        show_all ();

        response.connect (on_response);
    }

    private void on_response (Gtk.Dialog source, int response_id) {
        switch (response_id) {
        case Gtk.ResponseType.OK:
            GearyApplication.instance.config.ask_open_attachment = !checkbox.active;
	        break;
        case Gtk.ResponseType.CLOSE:
	        destroy ();
	        break;
        }
    }
}
