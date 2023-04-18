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

public class Mail.FolderList : Gtk.Box {
    public signal void folder_selected (Gee.Map<Mail.Backend.Account, string?> folder_full_name_per_account_uid);

    public Gtk.HeaderBar header_bar;

    private ListStore root_model;
    private Gtk.TreeListModel tree_list;
    private Gtk.SingleSelection selection_model;
    private static GLib.Settings settings;

    static construct {
        settings = new GLib.Settings ("io.elementary.mail");
    }

    construct {
        var application_instance = (Gtk.Application) GLib.Application.get_default ();

        var compose_button = new Gtk.Button.from_icon_name ("mail-message-new") {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_COMPOSE_MESSAGE,
            halign = Gtk.Align.START
        };
        compose_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (compose_button.action_name),
            _("Compose new message")
        );
        compose_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        var window_controls = new Gtk.WindowControls (START);

        header_bar = new Gtk.HeaderBar () {
            show_title_buttons = false,
            title_widget = new Gtk.Label ("")
        };
        header_bar.pack_start (window_controls);
        header_bar.pack_end (compose_button);
        header_bar.add_css_class (Granite.STYLE_CLASS_FLAT);

        root_model = new ListStore (typeof(AccountItemModel));
        tree_list = new Gtk.TreeListModel (root_model, false, false, create_folder_list_func);
        selection_model = new Gtk.SingleSelection (tree_list);
        var list_factory = new Gtk.SignalListItemFactory ();

        var folder_list_view = new Gtk.ListView (selection_model, list_factory);

        var scrolled_window = new Gtk.ScrolledWindow () {
            child = folder_list_view,
            vexpand = true
        };

        orientation = VERTICAL;
        width_request = 100;
        add_css_class (Granite.STYLE_CLASS_SIDEBAR);
        append (header_bar);
        append (scrolled_window);

        list_factory.setup.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;

            var tree_expander = new Gtk.TreeExpander () {
                child = new FolderListItem (),
                // indent_for_icon = false
            };

            list_item.child = tree_expander;
        });

        list_factory.bind.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;

            var expander = (Gtk.TreeExpander) list_item.child;
            var list_row = expander.list_row = tree_list.get_row (list_item.get_position());

            var item = (ItemModel) expander.list_row.item;

            var account_settings = new GLib.Settings.with_path ("io.elementary.mail.accounts", "/io/elementary/mail/accounts/%s/".printf (item.get_account_uid ()));

            if (item is AccountItemModel) {
                ((FolderListItem)expander.child).bind_account ((AccountItemModel)item);
                account_settings.bind ("expanded", list_row, "expanded", SettingsBindFlags.DEFAULT | SettingsBindFlags.GET_NO_CHANGES);
            } else if (item is FolderItemModel) {
                var folder_item = (FolderItemModel)item;

                ((FolderListItem)expander.child).bind_folder (folder_item);

                if (folder_item.full_name in account_settings.get_strv ("expanded-folders")) {
                    list_row.expanded = true;
                }

                list_row.notify["expanded"].connect (() => {
                    var folders = account_settings.get_strv ("expanded-folders");
                    if (list_row.expanded) {
                        folders += folder_item.full_name;
                    } else {
                        string[] new_folders = {};
                        foreach (var folder in folders) {
                            if (folder != folder_item.full_name) {
                                new_folders += folder;
                            }
                        }

                        folders = new_folders;
                    }

                    account_settings.set_strv ("expanded-folders", folders);
                });
            }
        });

        var session = Mail.Backend.Session.get_default ();

        session.get_accounts ().foreach ((account) => {
            add_account (account);
            return true;
        });

        session.account_added.connect (add_account);

        selection_model.selection_changed.connect ((position) => {
            var item = ((Gtk.TreeListRow)selection_model.get_selected_item()).get_item ();

            if (item is FolderItemModel) {
                var folder_name_per_account_uid = new Gee.HashMap<Mail.Backend.Account, string?> ();
                folder_name_per_account_uid.set (item.account, item.full_name);
                folder_selected (folder_name_per_account_uid.read_only_view);

                // settings.set ("selected-folder", "(ss)", folder_info.store.uid, folder_info.folder_info.full_name);
            }
        });
    }

    public ListModel? create_folder_list_func (Object item) {
        if (item is AccountItemModel) {
            return item.folder_list;
        } else if (item is FolderItemModel) {
            return item.folder_list;
        }
        return null;
    }

    private void add_account (Mail.Backend.Account account) {
        var account_item = new AccountItemModel (account);
        root_model.append (account_item);
    }
}

public interface ItemModel : Object {
    public abstract string get_account_uid ();
}
