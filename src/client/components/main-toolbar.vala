/* Copyright 2011-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

// Draws the main toolbar.
public class MainToolbar : Gtk.Box {
    public FolderMenu copy_folder_menu { get; private set; default = new FolderMenu(); }
    public FolderMenu move_folder_menu { get; private set; default = new FolderMenu(); }
    public string account { get; set; }
    public string folder { get; set; }
    public string search_text { get { return search_entry.text; } }
    public bool search_entry_has_focus { get { return search_entry.has_focus; } }
    public bool show_close_button { get; set; default = false; }
    public bool show_close_button_left { get; private set; default = true; }
    public bool show_close_button_right { get; private set; default = true; }
    public bool search_open { get; set; default = false; }
    public int left_pane_width { get; set; }

    private PillHeaderbar folder_header;
    private PillHeaderbar conversation_header;
    private Gtk.Button archive_button;
    private Gtk.Button trash_delete_button;
    private Binding guest_header_binding;
    private Gtk.SearchEntry search_entry = new Gtk.SearchEntry();
    private Geary.ProgressMonitor? search_upgrade_progress_monitor = null;
    private MonitoredProgressBar search_upgrade_progress_bar = new MonitoredProgressBar();
    private Geary.Account? current_account = null;

    private const string DEFAULT_SEARCH_TEXT = _("Search");

    public signal void search_text_changed(string search_text);

    public MainToolbar() {
        Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);

        folder_header = new PillHeaderbar(GearyApplication.instance.actions);
        conversation_header = new PillHeaderbar(GearyApplication.instance.actions);
        folder_header.get_style_context().add_class("titlebar");
        folder_header.get_style_context().add_class("geary-titlebar-left");
        conversation_header.get_style_context().add_class("titlebar");
        conversation_header.get_style_context().add_class("geary-titlebar-right");

        // Instead of putting a separator between the two headerbars, as other applications do,
        // we put a separator at the right end of the left headerbar.  This greatly improves
        // the appearance under the Ambiance theme (see bug #746171).  To get this separator to
        // line up with the handle of the pane, we need to extend the width of the left-hand
        // headerbar a bit.  Six pixels is right both for Adwaita and Ambiance.
        GearyApplication.instance.config.bind(Configuration.MESSAGES_PANE_POSITION_KEY,
            this, "left-pane-width", SettingsBindFlags.GET);
        this.bind_property("left-pane-width", folder_header, "width-request",
            BindingFlags.SYNC_CREATE, (binding, source_value, ref target_value) => {
                target_value = left_pane_width;
                return true;
            });

        this.bind_property("show-close-button-left", folder_header, "show-close-button",
            BindingFlags.SYNC_CREATE);
        this.bind_property("show-close-button-right", conversation_header, "show-close-button",
            BindingFlags.SYNC_CREATE);

        bool rtl = get_direction() == Gtk.TextDirection.RTL;
        GearyApplication.instance.controller.account_selected.connect(on_account_changed);

        // Assemble mark menu.
        GearyApplication.instance.load_ui_file("toolbar_mark_menu.ui");
        Gtk.Menu mark_menu = (Gtk.Menu) GearyApplication.instance.ui_manager.get_widget("/ui/ToolbarMarkMenu");
        mark_menu.foreach(GtkUtil.show_menuitem_accel_labels);

        // Toolbar setup.
        Gee.List<Gtk.Button> insert = new Gee.ArrayList<Gtk.Button>();

        // Compose.
        Gtk.Button compose = new Gtk.Button();
        compose.related_action = GearyApplication.instance.actions.get_action(GearyController.ACTION_NEW_MESSAGE);
        compose.tooltip_text = compose.related_action.tooltip;
        compose.image = new Gtk.Image.from_icon_name("mail-message-new", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work
        folder_header.pack_start(compose);

        // Assemble the empty menu
        GearyApplication.instance.load_ui_file("toolbar_empty_menu.ui");
        Gtk.Menu empty_menu = (Gtk.Menu) GearyApplication.instance.ui_manager.get_widget("/ui/ToolbarEmptyMenu");
        empty_menu.foreach(GtkUtil.show_menuitem_accel_labels);
        insert.clear();
        insert.add(folder_header.create_menu_button(null, empty_menu,
            GearyController.ACTION_EMPTY_MENU));
        Gtk.Box empty = folder_header.create_pill_buttons(insert, false);

        // Search bar.
        search_entry.width_chars = 28;
        search_entry.tooltip_text = _("Search all mail in account for keywords (Ctrl+S)");
        search_entry.valign = Gtk.Align.CENTER;
        search_entry.changed.connect(on_search_entry_changed);
        search_entry.key_press_event.connect(on_search_key_press);
        on_search_entry_changed(); // set initial state
        search_entry.has_focus = true;

        // Search upgrade progress bar.
        search_upgrade_progress_bar.margin_top = 3;
        search_upgrade_progress_bar.margin_bottom = 3;
        search_upgrade_progress_bar.show_text = true;
        search_upgrade_progress_bar.visible = false;
        search_upgrade_progress_bar.no_show_all = true;

        set_search_placeholder_text(DEFAULT_SEARCH_TEXT);

        folder_header.add_end(empty);
        folder_header.add_end(search_entry);
        folder_header.add_end(search_upgrade_progress_bar);
        folder_header.add_end(new Gtk.Separator(Gtk.Orientation.VERTICAL));

        // Reply buttons
        insert.clear();
        insert.add(conversation_header.create_toolbar_button(rtl ? "mail-reply-sender-rtl-symbolic"
            : "mail-reply-sender-symbolic", GearyController.ACTION_REPLY_TO_MESSAGE));
        insert.add(conversation_header.create_toolbar_button(rtl ? "mail-reply-all-rtl-symbolic"
            : "mail-reply-all-symbolic", GearyController.ACTION_REPLY_ALL_MESSAGE));
        insert.add(conversation_header.create_toolbar_button(rtl ? "mail-forward-rtl-symbolic"
            : "mail-forward-symbolic", GearyController.ACTION_FORWARD_MESSAGE));
        conversation_header.add_start(conversation_header.create_pill_buttons(insert));

        // Mark, copy, move.
        Gtk.MenuButton mark = new Gtk.MenuButton();
        mark.image = new Gtk.Image.from_icon_name("edit-flag", Gtk.IconSize.LARGE_TOOLBAR);
        mark.popup = mark_menu;
        mark.tooltip_text = _("Mark conversation");

        Gtk.MenuButton tag = new Gtk.MenuButton();
        tag.image = new Gtk.Image.from_icon_name("tag-new", Gtk.IconSize.LARGE_TOOLBAR);
        tag.popup = copy_folder_menu;
        tag.tooltip_text = _("Add label to conversation");

        Gtk.MenuButton move = new Gtk.MenuButton();
        move.image = new Gtk.Image.from_icon_name("mail-move", Gtk.IconSize.LARGE_TOOLBAR);
        move.popup = move_folder_menu;
        move.tooltip_text = _("Move conversation");

        conversation_header.pack_start(mark);
        conversation_header.pack_start(tag);
        conversation_header.pack_start(move);

        Gtk.Button trash_delete = new Gtk.Button();
        trash_delete.related_action = GearyApplication.instance.actions.get_action(GearyController.ACTION_TRASH_MESSAGE);
        trash_delete.tooltip_text = trash_delete.related_action.tooltip;
        trash_delete.image = new Gtk.Image.from_icon_name("edit-delete", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

        insert.clear();
        insert.add(archive_button = conversation_header.create_toolbar_button(null, GearyController.ACTION_ARCHIVE_MESSAGE, true));
        Gtk.Box archive_trash_delete = conversation_header.create_pill_buttons(insert);

        Gtk.Button undo = new Gtk.Button();
        undo.related_action = GearyApplication.instance.actions.get_action(GearyController.ACTION_UNDO);
        undo.tooltip_text = undo.related_action.tooltip;
        undo.related_action.notify["tooltip"].connect(() => { undo.tooltip_text = undo.related_action.tooltip; });
        undo.image = new Gtk.Image.from_icon_name("edit-undo", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work


        Gtk.MenuButton menu = new Gtk.MenuButton();
        menu.image = new Gtk.Image.from_icon_name("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
        menu.popup = new Gtk.Menu.from_model(GearyApplication.instance.controller.app_menu);
        menu.tooltip_text = _("Menu");

        conversation_header.pack_end(menu);
        conversation_header.pack_end(undo);
        conversation_header.add_end(archive_trash_delete);
        conversation_header.pack_end(trash_delete);

        pack_start(folder_header, false, false);
        pack_start(conversation_header, true, true);

        Gtk.Settings.get_default().notify["gtk-decoration-layout"].connect(set_window_buttons);
        realize.connect(set_window_buttons);
    }

    /// Updates the trash button as trash or delete, and shows or hides the archive button.
    public void update_trash_archive_buttons(bool trash, bool archive) {
        string action_name = (trash ? GearyController.ACTION_TRASH_MESSAGE
            : GearyController.ACTION_DELETE_MESSAGE);
        conversation_header.setup_button(trash_delete_button, null, action_name, false);

        archive_button.visible = archive;
    }

    public void set_conversation_header(Gtk.HeaderBar header) {
        conversation_header.hide();
        header.get_style_context().add_class("titlebar");
        header.get_style_context().add_class("geary-titlebar-right");
        guest_header_binding = bind_property("show-close-button-right", header,
            "show-close-button", BindingFlags.SYNC_CREATE);
        pack_start(header, true, true);
        header.decoration_layout = conversation_header.decoration_layout;
    }

    public void remove_conversation_header(Gtk.HeaderBar header) {
        remove(header);
        header.get_style_context().remove_class("titlebar");
        header.get_style_context().remove_class("geary-titlebar-right");
        GtkUtil.unbind(guest_header_binding);
        header.show_close_button = false;
        header.decoration_layout = Gtk.Settings.get_default().gtk_decoration_layout;
        conversation_header.show();
    }

    private void set_window_buttons() {
        string[] buttons = Gtk.Settings.get_default().gtk_decoration_layout.split(":");
        if (buttons.length != 2) {
            warning("gtk_decoration_layout in unexpected format");
            return;
        }
        show_close_button_left = show_close_button;
        show_close_button_right = show_close_button;
        folder_header.decoration_layout = buttons[0] + ":";
        conversation_header.decoration_layout = ":" + buttons[1];
    }

    public void set_search_text(string text) {
        search_entry.text = text;
    }

    public void give_search_focus() {
        search_entry.grab_focus();
    }

    public void set_search_placeholder_text(string placeholder) {
        search_entry.placeholder_text = placeholder;
    }

    private void on_search_entry_changed() {
        search_text_changed(search_entry.text);
        // Enable/disable clear button.
        search_entry.secondary_icon_name = search_entry.text != "" ?
            ("edit-clear-symbolic") : null;
    }

    private bool on_search_key_press(Gdk.EventKey event) {
        // Clear box if user hits escape.
        if (Gdk.keyval_name(event.keyval) == "Escape")
            search_entry.text = "";

        // Force search if user hits enter.
        if (Gdk.keyval_name(event.keyval) == "Return")
            on_search_entry_changed();

        return false;
    }

    private void on_search_upgrade_start() {
        // Set the progress bar's width to match the search entry's width.
        int minimum_width = 0;
        int natural_width = 0;
        search_entry.get_preferred_width(out minimum_width, out natural_width);
        search_upgrade_progress_bar.width_request = minimum_width;

        search_entry.hide();
        search_upgrade_progress_bar.show();
    }

    private void on_search_upgrade_finished() {
        search_entry.show();
        search_upgrade_progress_bar.hide();
    }

    private void on_account_changed(Geary.Account? account) {
        on_search_upgrade_finished(); // Reset search box.

        if (search_upgrade_progress_monitor != null) {
            search_upgrade_progress_monitor.start.disconnect(on_search_upgrade_start);
            search_upgrade_progress_monitor.finish.disconnect(on_search_upgrade_finished);
            search_upgrade_progress_monitor = null;
        }

        if (current_account != null) {
            current_account.information.notify[Geary.AccountInformation.PROP_NICKNAME].disconnect(
                on_nickname_changed);
        }

        if (account != null) {
            search_upgrade_progress_monitor = account.search_upgrade_monitor;
            search_upgrade_progress_bar.set_progress_monitor(search_upgrade_progress_monitor);

            search_upgrade_progress_monitor.start.connect(on_search_upgrade_start);
            search_upgrade_progress_monitor.finish.connect(on_search_upgrade_finished);
            if (search_upgrade_progress_monitor.is_in_progress)
                on_search_upgrade_start(); // Remove search box, we're already in progress.

            account.information.notify[Geary.AccountInformation.PROP_NICKNAME].connect(
                on_nickname_changed);

            search_upgrade_progress_bar.text = _("Indexing %s account").printf(account.information.nickname);
        }

        current_account = account;

        on_nickname_changed(); // Set new account name.
    }

    private void on_nickname_changed() {
        if (current_account == null ||GearyApplication.instance.controller.get_num_accounts() == 1) {
            set_search_placeholder_text(DEFAULT_SEARCH_TEXT);
        } else {
            set_search_placeholder_text (_("Search %s").printf(current_account.information.nickname));
        }
    }
}

