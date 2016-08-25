// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2011-2015 Yorba Foundation
 * Copyright (c) 2016 elementary LLC.
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

public class MainToolbar : Gtk.HeaderBar {
    public FolderMenu copy_folder_menu { get; private set; default = new FolderMenu (); }
    public FolderMenu move_folder_menu { get; private set; default = new FolderMenu (); }
    public string account { get; set; }
    public string folder { get; set; }
    public bool search_open { get; set; default = false; }
    public int left_pane_width { get; set; }

    private Gtk.Box folder_header;
    private Gtk.Grid conversation_header;
    private Gtk.Button archive_button;
    private Gtk.Button trash_delete;
    private Binding guest_header_binding;
    private Gtk.SearchEntry search_entry;
    private Geary.ProgressMonitor? search_upgrade_progress_monitor = null;
    private MonitoredProgressBar search_upgrade_progress_bar;
    private Geary.Account? current_account = null;

    private const string DEFAULT_SEARCH_TEXT = _("Search Mail");

    public signal void search_text_changed (string search_text);

    public MainToolbar () {
        show_close_button = true;
        set_custom_title (new Gtk.Label (null)); //Set title as a null label so that it doesn't take up space
        set_resize_mode (Gtk.ResizeMode.QUEUE); //without this, toolbar rapidly expands and forces the window larger than the screen

        GearyApplication.instance.controller.account_selected.connect (on_account_changed);

        // Assemble mark menu.
        try {
            GearyApplication.instance.ui_manager.add_ui_from_resource("%s/toolbar_mark_menu.ui".printf(GearyApplication.GRESOURCE_UI_PREFIX));
        } catch (Error e) {
            critical (e.message);
        }
        var mark_menu = (Gtk.Menu) GearyApplication.instance.ui_manager.get_widget ("/ui/ToolbarMarkMenu");
        mark_menu.foreach (GtkUtil.show_menuitem_accel_labels);

        var compose = new Gtk.Button ();
        compose.halign = Gtk.Align.START;
        compose.related_action = GearyApplication.instance.actions.get_action (GearyController.ACTION_NEW_MESSAGE);
        compose.tooltip_text = _("Compose new message (Ctrl+N, N)");
        compose.image = new Gtk.Image.from_icon_name ("mail-message-new", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

        // Set accel labels for EmptyTrash and EmptySpam context menus
        try {
            GearyApplication.instance.ui_manager.add_ui_from_resource("%s/context_empty_menu.ui".printf(GearyApplication.GRESOURCE_UI_PREFIX));
        } catch (Error e) {
            critical (e.message);
        }
        var empty_menu = (Gtk.Menu) GearyApplication.instance.ui_manager.get_widget ("/ui/ContextEmptyMenu");
        empty_menu.foreach (GtkUtil.show_menuitem_accel_labels);

        search_entry = new Gtk.SearchEntry ();
        search_entry.width_chars = 28;
        search_entry.tooltip_text = _("Search all mail in account for keywords (Ctrl+S)");
        search_entry.valign = Gtk.Align.CENTER;
        search_entry.search_changed.connect (on_search_entry_changed);
        search_entry.key_press_event.connect (on_search_key_press);
        search_entry.has_focus = true;

        search_upgrade_progress_bar = new MonitoredProgressBar ();
        search_upgrade_progress_bar.margin_top = 3;
        search_upgrade_progress_bar.margin_bottom = 3;
        search_upgrade_progress_bar.show_text = true;
        search_upgrade_progress_bar.visible = false;
        search_upgrade_progress_bar.no_show_all = true;

        set_search_placeholder_text (DEFAULT_SEARCH_TEXT);

        folder_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        folder_header.pack_start (compose);
        folder_header.pack_end (search_entry);
        folder_header.pack_end (search_upgrade_progress_bar);

        // FIXME: This doesn't play nice with changing window decoration layout
        GearyApplication.instance.config.bind (Configuration.MESSAGES_PANE_POSITION_KEY, this, "left-pane-width", SettingsBindFlags.GET);
        bind_property ("left-pane-width", folder_header, "width-request", BindingFlags.SYNC_CREATE, (binding, source_value, ref target_value) => {
            target_value = left_pane_width - 43;
            return true;
        });

        var reply = new Gtk.Button ();
        reply.related_action = GearyApplication.instance.actions.get_action (GearyController.ACTION_REPLY_TO_MESSAGE);
        reply.tooltip_text = _("Reply (Ctrl+R, R)");
        reply.image = new Gtk.Image.from_icon_name ("mail-reply-sender", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

        var reply_all = new Gtk.Button ();
        reply_all.related_action = GearyApplication.instance.actions.get_action (GearyController.ACTION_REPLY_ALL_MESSAGE);
        reply_all.tooltip_text = _("Reply all (Ctrl+Shift+R, Shift+R)");
        reply_all.image = new Gtk.Image.from_icon_name ("mail-reply-all", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

        var forward = new Gtk.Button();
        forward.related_action = GearyApplication.instance.actions.get_action (GearyController.ACTION_FORWARD_MESSAGE);
        forward.tooltip_text = _("Forward (Ctrl+Shift+F)");
        forward.image = new Gtk.Image.from_icon_name ("mail-forward", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

        var mark = new Gtk.MenuButton ();
        mark.image = new Gtk.Image.from_icon_name ("edit-flag", Gtk.IconSize.LARGE_TOOLBAR);
        mark.popup = mark_menu;
        mark.related_action = GearyApplication.instance.actions.get_action(GearyController.ACTION_MARK_AS_MENU);
        mark.tooltip_text = _("Mark conversation");

        var tag = new Gtk.MenuButton ();
        tag.image = new Gtk.Image.from_icon_name ("tag-new", Gtk.IconSize.LARGE_TOOLBAR);
        tag.popup = copy_folder_menu;
        tag.tooltip_text = _("Add label to conversation");

        var move = new Gtk.MenuButton ();
        move.image = new Gtk.Image.from_icon_name ("mail-move", Gtk.IconSize.LARGE_TOOLBAR);
        move.popup = move_folder_menu;
        move.tooltip_text = _("Move conversation");

        trash_delete = new Gtk.Button ();
        trash_delete.related_action = GearyApplication.instance.actions.get_action (GearyController.ACTION_TRASH_MESSAGE);
        trash_delete.use_action_appearance = false;
        trash_delete.tooltip_text = trash_delete.related_action.tooltip;
        trash_delete.image = new Gtk.Image.from_icon_name ("edit-delete", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

        var archive = new Gtk.Button ();
        archive.related_action = GearyApplication.instance.actions.get_action (GearyController.ACTION_ARCHIVE_MESSAGE);
        archive.tooltip_text = archive.related_action.tooltip;
        archive.image = new Gtk.Image.from_icon_name ("mail-archive", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

        conversation_header = new Gtk.Grid ();
        conversation_header.column_spacing = 6;
        conversation_header.add (reply);
        conversation_header.add (reply_all);
        conversation_header.add (forward);
        conversation_header.add (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        conversation_header.add (archive);
        conversation_header.add (mark);
        conversation_header.add (trash_delete);
        conversation_header.add (new Gtk.Separator (Gtk.Orientation.VERTICAL));
        conversation_header.add (move);
        conversation_header.add (tag);

        var undo = new Gtk.Button ();
        undo.related_action = GearyApplication.instance.actions.get_action (GearyController.ACTION_UNDO);
        undo.tooltip_text = undo.related_action.tooltip;
        undo.related_action.notify["tooltip"].connect (() => { undo.tooltip_text = undo.related_action.tooltip; });
        undo.image = new Gtk.Image.from_icon_name ("edit-undo", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

        var menu = new Gtk.MenuButton ();
        menu.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
        menu.popup = new Gtk.Menu.from_model (GearyApplication.instance.controller.app_menu);
        menu.tooltip_text = _("Menu");

        add (folder_header);
        add (conversation_header);
        pack_end (menu);
        pack_end (undo);
    }

    public bool search_entry_has_focus {
        get {
            return search_entry.has_focus;
        }
        set {
            search_entry.grab_focus ();
        }
    }

    public string search_text {
        get {
            return search_entry.text;
        }
        set {
            search_entry.text = value;
        }
    }

    /// Updates the trash button as trash or delete, and shows or hides the archive button.
    public void update_trash_archive_buttons (bool trash, bool archive) {
        string action_name = (trash ? GearyController.ACTION_TRASH_MESSAGE : GearyController.ACTION_DELETE_MESSAGE);

        trash_delete.related_action = GearyApplication.instance.actions.get_action (action_name);
        trash_delete.tooltip_text = trash_delete.related_action.tooltip;
        archive_button.visible = archive;
    }

    public void set_conversation_header (Gtk.HeaderBar header) {
        conversation_header.hide ();
        pack_start (header);
    }

    public void remove_conversation_header (Gtk.HeaderBar header) {
        remove (header);
        GtkUtil.unbind (guest_header_binding);
        conversation_header.show ();
    }

    public void set_search_placeholder_text (string placeholder) {
        search_entry.placeholder_text = placeholder;
    }

    private void on_search_entry_changed () {
        search_text_changed (search_entry.text);
    }

    private bool on_search_key_press (Gdk.EventKey event) {
        // Clear box if user hits escape.
        if (Gdk.keyval_name (event.keyval) == "Escape") {
            search_entry.text = "";
        }

        // Force search if user hits enter.
        if (Gdk.keyval_name (event.keyval) == "Return") {
            on_search_entry_changed ();
        }

        return false;
    }

    private void on_search_upgrade_start () {
        // Set the progress bar's width to match the search entry's width.
        int minimum_width = 0;
        int natural_width = 0;
        search_entry.get_preferred_width (out minimum_width, out natural_width);
        search_upgrade_progress_bar.width_request = minimum_width;

        search_entry.hide ();
        search_upgrade_progress_bar.show ();
    }

    private void on_search_upgrade_finished () {
        search_entry.show ();
        search_upgrade_progress_bar.hide ();
    }

    private void on_account_changed (Geary.Account? account) {
        on_search_upgrade_finished (); // Reset search box.

        if (search_upgrade_progress_monitor != null) {
            search_upgrade_progress_monitor.start.disconnect (on_search_upgrade_start);
            search_upgrade_progress_monitor.finish.disconnect (on_search_upgrade_finished);
            search_upgrade_progress_monitor = null;
        }

        if (current_account != null) {
            current_account.information.notify[Geary.AccountInformation.PROP_NICKNAME].disconnect (on_nickname_changed);
        }

        if (account != null) {
            search_upgrade_progress_monitor = account.search_upgrade_monitor;
            search_upgrade_progress_bar.set_progress_monitor (search_upgrade_progress_monitor);

            search_upgrade_progress_monitor.start.connect (on_search_upgrade_start);
            search_upgrade_progress_monitor.finish.connect (on_search_upgrade_finished);
            if (search_upgrade_progress_monitor.is_in_progress) {
                on_search_upgrade_start (); // Remove search box, we're already in progress.
            }

            account.information.notify[Geary.AccountInformation.PROP_NICKNAME].connect (on_nickname_changed);

            search_upgrade_progress_bar.text = _("Indexing %s account").printf (account.information.nickname);
        }

        current_account = account;

        on_nickname_changed (); // Set new account name.
    }

    private void on_nickname_changed () {
        if (current_account == null ||GearyApplication.instance.controller.get_num_accounts () == 1) {
            set_search_placeholder_text (DEFAULT_SEARCH_TEXT);
        } else {
            set_search_placeholder_text (_("Search %s").printf (current_account.information.nickname));
        }
    }
}

