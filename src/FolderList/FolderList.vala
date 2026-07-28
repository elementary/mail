/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017-2026 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.FolderList : Gtk.Box {
    public signal void folder_selected (Gee.Map<Backend.Account, Camel.FolderInfo?> folder_info_per_account);

    public Hdy.HeaderBar header_bar { get; private set; }

    private Mail.SourceList source_list;
    private Mail.SessionItemModel session_source_item;
    private static GLib.Settings settings;

    static construct {
        settings = new GLib.Settings ("io.elementary.mail");
    }

    construct {
        var application_instance = (Gtk.Application) GLib.Application.get_default ();

        var compose_button = new Gtk.Button.from_icon_name ("mail-message-new", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_COMPOSE_MESSAGE,
            halign = START
        };
        compose_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (compose_button.action_name),
            _("Compose new message")
        );

        header_bar = new Hdy.HeaderBar () {
            show_close_button = true
        };
        header_bar.pack_end (compose_button);
        header_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var session = Mail.Backend.Session.get_default ();

        session_source_item = new Mail.SessionItemModel (session);

        source_list = new Mail.SourceList ();
        source_list.root.add (session_source_item);

        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            child = source_list
        };

        var load_images_menuitem = new Granite.SwitchModelButton (_("Always Show Remote Images"));

        var manage_signatures_menuitem = new Gtk.ModelButton () {
            text = _("Edit Signatures…"),
            action_name = Application.ACTION_PREFIX + Application.ACTION_MANAGE_SIGNATURES,
        };

        var account_settings_menuitem = new Gtk.ModelButton () {
            text = _("Account Settings…")
        };

        var app_menu_separator = new Gtk.Separator (HORIZONTAL) {
            margin_bottom = 3,
            margin_top = 3
        };

        var app_menu_box = new Gtk.Box (VERTICAL, 0) {
            margin_bottom = 3,
            margin_top = 3
        };
        app_menu_box.add (load_images_menuitem);
        app_menu_box.add (app_menu_separator);
        app_menu_box.add (manage_signatures_menuitem);
        app_menu_box.add (account_settings_menuitem);
        app_menu_box.show_all ();

        var app_menu_popover = new Gtk.Popover (null) {
            child = app_menu_box
        };

        var app_menu = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.SMALL_TOOLBAR),
            popover = app_menu_popover,
            tooltip_text = _("Menu")
        };

        var action_bar = new Gtk.ActionBar ();
        action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        action_bar.pack_end (app_menu);

        orientation = VERTICAL;
        width_request = 100;
        get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);
        add (header_bar);
        add (scrolled_window);
        add (action_bar);

        session.get_accounts ().foreach ((account) => {
            add_account (account);
            return true;
        });

        session.account_added.connect (add_account);

        source_list.item_selected.connect ((item) => {
            if (item == null) {
                return;
            }

            if (item is FolderItemModel) {
                var folder_info_per_account = new Gee.HashMap<Mail.Backend.Account, Camel.FolderInfo?> ();
                folder_info_per_account.set (item.account, item.folder_info);
                folder_selected (folder_info_per_account.read_only_view);

                settings.set ("selected-folder", "(ss)", item.account.service.uid, item.folder_info.full_name);

            } else if (item is GroupedFolderItemModel) {
                folder_selected (item.get_folder_info_per_account ());

                settings.set ("selected-folder", "(ss)", "GROUPED", item.name);
            }
        });

        settings.bind ("always-load-remote-images", load_images_menuitem, "active", SettingsBindFlags.DEFAULT);

        account_settings_menuitem.clicked.connect (() => {
            try {
                Gtk.show_uri_on_window ((Gtk.Window) get_toplevel (), "settings://accounts/online", Gtk.get_current_event_time ());
            } catch (Error e) {
                var dialog = new Granite.MessageDialog (
                    _("Unable to open System Settings"),
                    _("Open System Settings manually or install Evolution to set up online accounts."),
                    new ThemedIcon ("preferences-system")
                ) {
                    badge_icon = new ThemedIcon ("dialog-warning"),
                    modal = true,
                    transient_for = (Gtk.Window) get_toplevel ()
                };
                dialog.response.connect (dialog.destroy);
                dialog.present ();
            }
        });

        var edit_aliases_action = new SimpleAction ("account-edit-aliases", VariantType.STRING);
        edit_aliases_action.activate.connect ((param) => {
            new AliasDialog (param.get_string ()) {
                transient_for = (Gtk.Window) get_toplevel ()
            }.present ();
        });

        var action_group = new SimpleActionGroup ();
        action_group.add_action (edit_aliases_action);

        insert_action_group ("folder-list", action_group);
    }

    private void add_account (Mail.Backend.Account account) {
        var account_item = new Mail.AccountItemModel (account);
        account_item.start_edit.connect ((item) => source_list.start_editing_item (item));
        source_list.root.add (account_item);
        account_item.load.begin ((obj, res) => {
            account_item.load.end (res);

            string selected_folder_uid, selected_folder_name;
            settings.get ("selected-folder", "(ss)", out selected_folder_uid, out selected_folder_name);

            if (account.service.uid == selected_folder_uid) {
                select_saved_folder (account_item, selected_folder_name);
            } else if (selected_folder_uid == "GROUPED") {
                select_saved_folder (session_source_item, selected_folder_name);
            }
        });
    }

    private bool select_saved_folder (Mail.SourceList.ExpandableItem item, string selected_folder_name) {
        foreach (var child in item.children) {
            if (child is FolderItemModel) {
                if (select_saved_folder ((Mail.SourceList.ExpandableItem) child, selected_folder_name)) {
                    return true;
                }

                unowned FolderItemModel folder_item = (FolderItemModel) child;
                if (folder_item.folder_info.full_name == selected_folder_name) {
                    source_list.selected = child;

                    var folder_info_per_account = new Gee.HashMap<Mail.Backend.Account, Camel.FolderInfo?> ();
                    folder_info_per_account.set (folder_item.account, folder_item.folder_info);
                    folder_selected (folder_info_per_account.read_only_view);
                    return true;
                }
            } else if (child is GroupedFolderItemModel) {
                unowned GroupedFolderItemModel grouped_folder_item = (GroupedFolderItemModel) child;
                if (grouped_folder_item.name == selected_folder_name) {
                    source_list.selected = child;
                    folder_selected (grouped_folder_item.get_folder_info_per_account ());
                    return true;
                }
            }
        }

        return false;
    }
}
