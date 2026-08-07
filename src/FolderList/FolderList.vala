/*
 * SPDX-License-Identifier: LGPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017-2026 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.FolderList : Gtk.Box {
    public signal void folder_selected (Gee.Map<Backend.Account, Camel.FolderInfo?> folder_info_per_account);

    public const string ACTION_GROUP_PREFIX = "folder-list";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    public const string ACTION_EDIT_ALIASES = "edit-alises";

    public Adw.HeaderBar header_bar { get; private set; }

    private Mail.SourceList source_list;
    private Mail.SessionItemModel session_source_item;
    private static GLib.Settings settings;

    static construct {
        settings = new GLib.Settings ("io.elementary.mail");
    }

    construct {
        var application_instance = (Gtk.Application) GLib.Application.get_default ();

        var compose_button = new Gtk.Button.from_icon_name ("mail-message-new") {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_COMPOSE_MESSAGE,
            halign = START
        };
        compose_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (compose_button.action_name),
            _("Compose new message")
        );
        compose_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        header_bar = new Adw.HeaderBar () {
            show_start_title_buttons = true,
        };
        header_bar.pack_end (compose_button);
        header_bar.add_css_class (Granite.STYLE_CLASS_FLAT);

        var session = Mail.Backend.Session.get_default ();

        session_source_item = new Mail.SessionItemModel (session);

        source_list = new Mail.SourceList ();
        source_list.root.add (session_source_item);

        var scrolled_window = new Gtk.ScrolledWindow () {
            child = source_list
        };

        var dialogs_section = new Menu ();
        dialogs_section.append (_("Edit Signatures…"), Application.ACTION_PREFIX + Application.ACTION_MANAGE_SIGNATURES);
        dialogs_section.append (_("Account Settings…"), Application.ACTION_PREFIX + Application.ACTION_ACCOUNT_SETTINGS);

        var menu_model = new Menu ();
        menu_model.append (_("Always Show Remote Images"), Application.ACTION_PREFIX + Application.ACTION_LOAD_IMAGES);
        menu_model.append_section (null, dialogs_section);

        var app_menu = new Gtk.MenuButton () {
            icon_name = "open-menu-symbolic",
            menu_model = menu_model,
            tooltip_text = _("Menu")
            // use_popover = false
        };

        var action_bar = new Gtk.ActionBar ();
        action_bar.add_css_class (Granite.STYLE_CLASS_FLAT);
        action_bar.pack_end (app_menu);

        orientation = VERTICAL;
        width_request = 100;
        add_css_class (Granite.STYLE_CLASS_SIDEBAR);
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

        var edit_aliases_action = new SimpleAction (ACTION_EDIT_ALIASES, VariantType.STRING);
        edit_aliases_action.activate.connect ((param) => {
            new AliasDialog (param.get_string ()) {
                transient_for = (Gtk.Window) get_root ()
            }.present ();
        });

        var action_group = new SimpleActionGroup ();
        action_group.add_action (edit_aliases_action);

        insert_action_group (ACTION_GROUP_PREFIX, action_group);
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
