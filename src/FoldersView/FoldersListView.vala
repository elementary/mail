// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.FoldersListView : Gtk.Grid {
    public signal void folder_selected (Gee.Map<Backend.Account, string?> folder_full_name_per_account);

    public Hdy.HeaderBar header_bar { get; private set; }

    private Mail.SourceList source_list;
    private Mail.SessionSourceItem session_source_item;
    private static GLib.Settings settings;

    static construct {
        settings = new GLib.Settings ("io.elementary.mail");
    }

    construct {
        source_list = new Mail.SourceList ();

        var application_instance = (Gtk.Application) GLib.Application.get_default ();

        var compose_button = new Gtk.Button.from_icon_name ("mail-message-new", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_COMPOSE_MESSAGE,
            halign = Gtk.Align.START
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

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.add (source_list);

        var load_images_menuitem = new Granite.SwitchModelButton (_("Always Show Remote Images"));

        var account_settings_menuitem = new Gtk.ModelButton () {
            text = _("Account Settings…")
        };

        var app_menu_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
            margin_bottom = 3,
            margin_top = 3
        };

        var app_menu_box = new Gtk.Box (VERTICAL, 0) {
            margin_bottom = 3,
            margin_top = 3
        };
        app_menu_box.add (load_images_menuitem);
        app_menu_box.add (app_menu_separator);
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

        orientation = Gtk.Orientation.VERTICAL;
        width_request = 100;
        get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);
        add (header_bar);
        add (scrolled_window);
        add (action_bar);

        var session = Mail.Backend.Session.get_default ();

        session_source_item = new Mail.SessionSourceItem (session);
        source_list.root.add (session_source_item);

        session.get_accounts ().foreach ((account) => {
            add_account (account);
            return true;
        });

        session.account_added.connect (add_account);
        source_list.item_selected.connect ((item) => {
            if (item == null) {
                return;
            }

            if (item is FolderSourceItem) {
                unowned FolderSourceItem folder_item = (FolderSourceItem) item;
                var folder_name_per_account = new Gee.HashMap<Mail.Backend.Account, string?> ();
                folder_name_per_account.set (folder_item.account, folder_item.full_name);
                folder_selected (folder_name_per_account.read_only_view);

                settings.set ("selected-folder", "(ss)", folder_item.account.service.uid, folder_item.full_name);

            } else if (item is GroupedFolderSourceItem) {
                unowned GroupedFolderSourceItem grouped_folder_item = (GroupedFolderSourceItem) item;
                folder_selected (grouped_folder_item.get_folder_full_name_per_account ());

                settings.set ("selected-folder", "(ss)", "GROUPED", grouped_folder_item.name);
            }
        });

        var settings = new GLib.Settings ("io.elementary.mail");
        settings.bind ("always-load-remote-images", load_images_menuitem, "active", SettingsBindFlags.DEFAULT);

        account_settings_menuitem.clicked.connect (() => {
            try {
                Gtk.show_uri_on_window ((Gtk.Window) get_toplevel (), "settings://accounts/online", Gtk.get_current_event_time ());
            } catch (Error e) {
                critical ("Failed to open account settings: %s", e.message);
            }
        });
    }

    private void add_account (Mail.Backend.Account account) {
        var account_item = new Mail.AccountSourceItem (account);
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
            if (child is FolderSourceItem) {
                if (select_saved_folder ((Mail.SourceList.ExpandableItem) child, selected_folder_name)) {
                    return true;
                }

                unowned FolderSourceItem folder_item = (FolderSourceItem) child;
                if (folder_item.full_name == selected_folder_name) {
                    source_list.selected = child;

                    var folder_name_per_account = new Gee.HashMap<Mail.Backend.Account, string?> ();
                    folder_name_per_account.set (folder_item.account, folder_item.full_name);
                    folder_selected (folder_name_per_account.read_only_view);
                    return true;
                }
            } else if (child is GroupedFolderSourceItem) {
                unowned GroupedFolderSourceItem grouped_folder_item = (GroupedFolderSourceItem) child;
                if (grouped_folder_item.name == selected_folder_name) {
                    source_list.selected = child;
                    folder_selected (grouped_folder_item.get_folder_full_name_per_account ());
                    return true;
                }
            }
        }

        return false;
    }
}
