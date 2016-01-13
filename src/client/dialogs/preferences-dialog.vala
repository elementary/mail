/* Copyright 2011-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class PreferencesDialog : Object {
    private Gtk.Dialog dialog;
    private Gtk.Switch autoselect;
    private Gtk.Switch display_preview;
    private Gtk.Switch spell_check;
    private Gtk.Switch startup_notifications;
    private Gtk.Switch three_pane_view;
    private Gtk.Switch show_images;

    public PreferencesDialog (Gtk.Window parent) {
        dialog = new Gtk.Dialog ();
        dialog.border_width = 5;
        dialog.deletable = false;
        dialog.resizable = false;
        dialog.set_transient_for (parent);
        dialog.set_modal (true);

        Gtk.Label reading = new Gtk.Label (_("Reading"));
        reading.get_style_context ().add_class ("h4");
        reading.halign = Gtk.Align.START;

        autoselect = new Gtk.Switch ();
        Gtk.Label autoselect_label = new Gtk.Label (_("Automatically select next message:"));
        autoselect_label.halign = Gtk.Align.END;
        autoselect_label.margin_left = 12;

        display_preview = new Gtk.Switch ();
        Gtk.Label display_preview_label = new Gtk.Label (_("Conversation previews:"));
        display_preview_label.halign = Gtk.Align.END;
        display_preview_label.margin_left = 12;

        three_pane_view = new Gtk.Switch ();
        Gtk.Label three_pane_view_label = new Gtk.Label (_("Three-pane layout:"));
        three_pane_view_label.halign = Gtk.Align.END;
        three_pane_view_label.margin_left = 12;

        show_images = new Gtk.Switch ();
        Gtk.Label show_images_label = new Gtk.Label (_("Always show remote images in mail:"));
        show_images_label.halign = Gtk.Align.END;
        show_images_label.margin_left = 12;

        Gtk.Label composer = new Gtk.Label (_("Composer"));
        composer.get_style_context ().add_class ("h4");
        composer.halign = Gtk.Align.START;

        spell_check = new Gtk.Switch ();
        Gtk.Label spell_check_label = new Gtk.Label (_("Spell check:"));
        spell_check_label.halign = Gtk.Align.END;
        spell_check_label.margin_left = 12;

        Gtk.Label notifications = new Gtk.Label (_("Notifications"));
        notifications.get_style_context ().add_class ("h4");
        notifications.halign = Gtk.Align.START;

        startup_notifications = new Gtk.Switch ();
        Gtk.Label startup_notifications_label = new Gtk.Label (_("Always watch for new mail:"));
        startup_notifications_label.halign = Gtk.Align.END;
        startup_notifications_label.margin_left = 12;

        Gtk.Grid layout = new Gtk.Grid ();
        layout.column_spacing = 12;
        layout.row_spacing = 6;
        layout.margin = 5;
        layout.margin_bottom = 19;
        layout.margin_top = 0;

        layout.attach (reading, 0, 0, 1, 1);
        layout.attach (autoselect_label, 0, 1, 1, 1);
        layout.attach (autoselect, 1, 1, 1, 1);
        layout.attach (display_preview_label, 0, 2, 1, 1);
        layout.attach (display_preview, 1, 2, 1, 1);
        layout.attach (three_pane_view_label, 0, 3, 1, 1);
        layout.attach (three_pane_view, 1, 3, 1, 1);
        layout.attach (show_images_label, 0, 4, 1, 1);
        layout.attach (show_images, 1, 4, 1, 1);
        layout.attach (composer, 0, 5, 1, 1);
        layout.attach (spell_check_label, 0, 6, 1, 1);
        layout.attach (spell_check, 1, 6, 1, 1);
        layout.attach (notifications, 0, 7, 1, 1);
        layout.attach (startup_notifications_label, 0, 8, 1, 1);
        layout.attach (startup_notifications, 1, 8, 1, 1);

        Gtk.Box content = dialog.get_content_area () as Gtk.Box;
        content.add (layout);

        dialog.add_button (_("_Close"), Gtk.ResponseType.CLOSE);

        bind_keys ();
    }

    public void bind_keys () {
        Configuration config = GearyApplication.instance.config;
        config.bind (Configuration.AUTOSELECT_KEY, autoselect, "active");
        config.bind (Configuration.DISPLAY_PREVIEW_KEY, display_preview, "active");
        config.bind (Configuration.FOLDER_LIST_PANE_HORIZONTAL_KEY, three_pane_view, "active");
        config.bind (Configuration.SPELL_CHECK_KEY, spell_check, "active");
        config.bind (Configuration.STARTUP_NOTIFICATIONS_KEY, startup_notifications, "active");
        config.bind (Configuration.GENERALLY_SHOW_REMOTE_IMAGES_KEY, show_images, "active");
    }

    public void run () {
        // Sync startup notification option with file state
        GearyApplication.instance.controller.autostart_manager.sync_with_config ();
        dialog.show_all ();
        dialog.run ();
        dialog.destroy ();
    }
}

