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
    public bool show_close_button { get; set; default = false; }
    public bool show_close_button_left { get; private set; default = true; }
    public bool show_close_button_right { get; private set; default = true; }
    public bool search_open { get; set; default = false; }
    public int left_pane_width { get; set; }

    private PillHeaderbar folder_header;
    private Gtk.HeaderBar conversation_header;
    private Gtk.Button archive_button;
    private Gtk.Button trash_delete;
    private Binding guest_header_binding;

    public MainToolbar() {
        Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);

        folder_header = new PillHeaderbar(GearyApplication.instance.actions);
        conversation_header = new Gtk.HeaderBar ();
        folder_header.get_style_context().add_class("titlebar");
        folder_header.get_style_context().add_class("geary-titlebar-left");
        conversation_header.get_style_context().add_class("titlebar");

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

        this.bind_property("account", folder_header, "title", BindingFlags.SYNC_CREATE);
        this.bind_property("folder", folder_header, "subtitle", BindingFlags.SYNC_CREATE);

        this.bind_property("show-close-button-left", folder_header, "show-close-button",
            BindingFlags.SYNC_CREATE);
        this.bind_property("show-close-button-right", conversation_header, "show-close-button",
            BindingFlags.SYNC_CREATE);

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

        Gtk.MenuButton empty = new Gtk.MenuButton();
        empty.image = new Gtk.Image.from_icon_name("edit-clear", Gtk.IconSize.LARGE_TOOLBAR);
        empty.popup = empty_menu;
        empty.tooltip_text = _("Empty Spam or Trash folders");

        // Search
        insert.clear();
        Gtk.Button search_button = folder_header.create_toggle_button(
            "preferences-system-search-symbolic", GearyController.ACTION_TOGGLE_SEARCH);
        this.bind_property("search-open", search_button, "active",
            BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
        insert.add(search_button);
        Gtk.Box search = folder_header.create_pill_buttons(insert, false);

        folder_header.add_end(empty);
        folder_header.add_end(search);
        folder_header.add_end(new Gtk.Separator(Gtk.Orientation.VERTICAL));

        // Reply buttons
        Gtk.Button reply = new Gtk.Button();
        reply.related_action = GearyApplication.instance.actions.get_action(GearyController.ACTION_REPLY_TO_MESSAGE);
        reply.tooltip_text = reply.related_action.tooltip;
        reply.image = new Gtk.Image.from_icon_name("mail-reply-sender", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

        Gtk.Button reply_all = new Gtk.Button();
        reply_all.related_action = GearyApplication.instance.actions.get_action(GearyController.ACTION_REPLY_ALL_MESSAGE);
        reply_all.tooltip_text = reply_all.related_action.tooltip;
        reply_all.image = new Gtk.Image.from_icon_name("mail-reply-all", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

        Gtk.Button forward = new Gtk.Button();
        forward.related_action = GearyApplication.instance.actions.get_action(GearyController.ACTION_FORWARD_MESSAGE);
        forward.tooltip_text = forward.related_action.tooltip;
        forward.image = new Gtk.Image.from_icon_name("mail-forward", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

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

        conversation_header.pack_start(reply);
        conversation_header.pack_start(reply_all);
        conversation_header.pack_start(forward);
        conversation_header.pack_start(mark);
        conversation_header.pack_start(tag);
        conversation_header.pack_start(move);

        Gtk.Button trash_delete = new Gtk.Button();
        trash_delete.related_action = GearyApplication.instance.actions.get_action(GearyController.ACTION_TRASH_MESSAGE);
        trash_delete.tooltip_text = trash_delete.related_action.tooltip;
        trash_delete.image = new Gtk.Image.from_icon_name("edit-delete", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

        Gtk.Button archive = new Gtk.Button();
        archive.related_action = GearyApplication.instance.actions.get_action(GearyController.ACTION_ARCHIVE_MESSAGE);
        archive.tooltip_text = archive.related_action.tooltip;
        archive.image = new Gtk.Image.from_icon_name("mail-archive", Gtk.IconSize.LARGE_TOOLBAR); //FIXME: For some reason doing Button.from_icon_name doesn't work

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
        conversation_header.pack_end(archive);
        conversation_header.pack_end(trash_delete);

        pack_start(folder_header, false, false);
        pack_start(conversation_header, true, true);

        Gtk.Settings.get_default().notify["gtk-decoration-layout"].connect(set_window_buttons);
        realize.connect(set_window_buttons);
    }

    /// Updates the trash button as trash or delete, and shows or hides the archive button.
    public void update_trash_archive_buttons(bool trash, bool archive) {
        string action_name = (trash ? GearyController.ACTION_TRASH_MESSAGE : GearyController.ACTION_DELETE_MESSAGE);

        trash_delete.related_action = GearyApplication.instance.actions.get_action(action_name);
        trash_delete.tooltip_text = trash_delete.related_action.tooltip;
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
}

