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

public class Mail.FoldersListView : Gtk.Box {
    public signal void folder_selected (Gee.Map<Mail.Backend.Account, string?> folder_full_name_per_account_uid);

    public Adw.HeaderBar header_bar { get; private set; }

    private ListStore account_list;
    private ListStore real_account_list;
    private Gee.HashMap<string, Mail.FolderInfo> folder_info_per_account;
    private Gtk.TreeListModel folder_list;
    private Gtk.SingleSelection selection_model;
    private Gtk.ListView folder_list_view;
    private static GLib.Settings settings;

    static construct {
        settings = new GLib.Settings ("io.elementary.mail");
    }

    public delegate ListModel? TreeListModelCreateModelFunc (Object item);

    construct {
        var list_factory = new Gtk.SignalListItemFactory ();
        list_factory.setup.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;

            var tree_expander = new Gtk.TreeExpander () {
                indent_for_icon = false
                //indent_for_depth = false
            };

            var content_widget = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            content_widget.append (new Gtk.Image ());
            content_widget.append (new Gtk.Label (""));

            tree_expander.set_child(content_widget);
            list_item.set_child (tree_expander);
        });
        list_factory.bind.connect ((obj) => {
            var list_item = (Gtk.ListItem) obj;
            ((Gtk.TreeExpander)list_item.child).list_row = folder_list.get_row (list_item.get_position());
            var tree_expander = (Gtk.TreeExpander) list_item.get_child ();
            var content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            tree_expander.set_child (content_box);
            var model_item = ((Gtk.TreeListRow)list_item.get_item()).get_item ();
            if (model_item is Camel.OfflineStore) {
                var store_item = (Camel.OfflineStore) model_item;
                content_box.append(new Gtk.Label(store_item.display_name));
            } else if (model_item is Mail.FolderInfo) {
                var folder_info_item = (Mail.FolderInfo) model_item;
                var content_icon = new Gtk.Image ();
                var content_label = new Gtk.Label (folder_info_item.folder_info.display_name);
                var right_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true, homogeneous = true};
                if(folder_info_item.folder_info.unread > 0) {
                    var unread_messages_badge = new Gtk.Label (folder_info_item.folder_info.unread.to_string()) { halign = END };
                    right_box.append (unread_messages_badge);
                }
                content_box.append (content_icon);
                content_box.append (content_label);
                content_box.append (right_box);
                switch (folder_info_item.folder_info.flags & Camel.FOLDER_TYPE_MASK) {
                    case Camel.FolderInfoFlags.TYPE_INBOX:
                        content_icon.set_from_icon_name ("mail-inbox");
                        break;
                    case Camel.FolderInfoFlags.TYPE_OUTBOX:
                        content_icon.set_from_icon_name ("mail-outbox");
                        break;
                    case Camel.FolderInfoFlags.TYPE_ARCHIVE:
                        content_icon.set_from_icon_name ("mail-archive");
                        break;
                    case Camel.FolderInfoFlags.TYPE_TRASH:
                        content_icon.set_from_icon_name (folder_info_item.folder_info.total == 0 ? "user-trash" : "user-trash-full");
                        break;
                    case Camel.FolderInfoFlags.TYPE_SENT:
                        content_icon.set_from_icon_name ("mail-sent");
                        break;
                    case Camel.FolderInfoFlags.TYPE_DRAFTS:
                        content_icon.set_from_icon_name ("mail-drafts");
                        break;
                    case Camel.FolderInfoFlags.TYPE_JUNK:
                        content_icon.set_from_icon_name ("edit-flag");
                        break;
                    default:
                        content_icon.set_from_icon_name ("folder");
                }
            }
        });

        real_account_list = new ListStore (typeof(Mail.Backend.Account));
        account_list = new ListStore (typeof(Camel.OfflineStore));
        folder_info_per_account = new Gee.HashMap<string, Mail.FolderInfo> ();
        folder_list = new Gtk.TreeListModel (account_list, false, false, create_folder_list_func);
        selection_model = new Gtk.SingleSelection (folder_list);

        folder_list_view = new Gtk.ListView (selection_model, list_factory);

        var application_instance = (Gtk.Application) GLib.Application.get_default ();

        var compose_button = new Gtk.Button.from_icon_name ("mail-message-new") {
            action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_COMPOSE_MESSAGE,
            halign = Gtk.Align.START
        };
        compose_button.tooltip_markup = Granite.markup_accel_tooltip (
            application_instance.get_accels_for_action (compose_button.action_name),
            _("Compose new message")
        );

        header_bar = new Adw.HeaderBar ();
        header_bar.pack_end (compose_button);
        header_bar.add_css_class (Granite.STYLE_CLASS_FLAT);

        var scrolled_window = new Gtk.ScrolledWindow () {
            child = folder_list_view,
            vexpand = true
        };

        orientation = Gtk.Orientation.VERTICAL;
        width_request = 100;
        append (header_bar);
        append (scrolled_window);

        var session = Mail.Backend.Session.get_default ();

        session.get_accounts ().foreach ((account) => {
            add_account (account);
            return true;
        });

        session.account_added.connect (add_account);

        selection_model.selection_changed.connect ((position) => {
            var item = ((Gtk.TreeListRow)selection_model.get_selected_item()).get_item ();

            if (item is Mail.FolderInfo) {
                unowned Mail.FolderInfo folder_info = (Mail.FolderInfo) item;
                var folder_name_per_account_uid = new Gee.HashMap<Mail.Backend.Account, string?> ();
                folder_name_per_account_uid.set ((Mail.Backend.Account)real_account_list.get_item (0), folder_info.folder_info.full_name);
                folder_selected (folder_name_per_account_uid.read_only_view);

                settings.set ("selected-folder", "(ss)", folder_info.store.uid, folder_info.folder_info.full_name);
            }
        });
    }

    public ListModel? create_folder_list_func (Object item) {
        if(item is Camel.OfflineStore) {
            var store = (Camel.OfflineStore) item;
            var store_root_folder_list = new ListStore (typeof(Mail.FolderInfo));

            if (folder_info_per_account[store.uid] != null) {
                var current_folder_info = folder_info_per_account[store.uid].folder_info;
                while (current_folder_info != null) {
                    store_root_folder_list.append (new Mail.FolderInfo (store, current_folder_info));
                    current_folder_info = current_folder_info.next;
                }
            } else {
                critical ("No Information about the folder structure found for account %s", store.display_name);
            }

            return store_root_folder_list;

        } else if (item is Mail.FolderInfo) {
            var folder_item = (Mail.FolderInfo) item;
            if(folder_item.folder_info.child != null) {
                var subfolder_list = new ListStore (typeof(Mail.FolderInfo));

                var current_folder_info = (Camel.FolderInfo) folder_item.folder_info.child;
                while (current_folder_info != null) {
                    subfolder_list.append(new Mail.FolderInfo (folder_item.store, current_folder_info));
                    current_folder_info = current_folder_info.next;
                }

                return subfolder_list;
            }
        }
        return null;
    }

    private void add_account (Mail.Backend.Account account) {
        if(account != null) {
            real_account_list.append(account);
            var offlinestore = (Camel.OfflineStore) account.service;
            offlinestore.get_folder_info.begin (null, Camel.StoreGetFolderInfoFlags.FAST, Priority.DEFAULT, null, (obj, res) => {
                try {
                    var folder_info = offlinestore.get_folder_info.end (res);
                    folder_info_per_account[offlinestore.uid] = new Mail.FolderInfo (offlinestore, folder_info);

                    account_list.append (offlinestore);

                    var folder_settings = new GLib.Settings.with_path ("io.elementary.mail.accounts", "/io/elementary/mail/accounts/%s/".printf (account.service.uid));
                    expand_saved_folders (folder_list.get_child_row(((int)account_list.get_n_items ()) - 1), 0, folder_settings);

                    string selected_folder_uid, selected_folder_name;

                    settings.get ("selected-folder", "(ss)", out selected_folder_uid, out selected_folder_name);

                    if(selected_folder_uid == offlinestore.uid) {
                        select_saved_folder (folder_list.get_child_row(((int)account_list.get_n_items ()) - 1), 0, selected_folder_name);
                    }
                } catch (Error e) {
                    critical ("Unable to retrieve Folder Information from account %s: %s", offlinestore.display_name, e.message);
                }
            });
            offlinestore.folder_info_stale.connect (() => {
                refresh_folder_info (offlinestore);
            });
        }
    }

    private void select_saved_folder (Gtk.TreeListRow? tree_row, int i, string selected_folder_full_name) {
        if (tree_row == null) {
            return;
        }

        if(tree_row.get_child_row (i) != null) {
            select_saved_folder (tree_row.get_child_row (i), 0, selected_folder_full_name);

            var item = tree_row.get_child_row (i).get_item ();

            if(item is Mail.FolderInfo && item.folder_info.full_name == selected_folder_full_name) {
                selection_model.set_selected (tree_row.get_child_row(i).get_position());
                return;
            }
            select_saved_folder (tree_row, i + 1, selected_folder_full_name);
        }
    }

    private void expand_saved_folders (Gtk.TreeListRow? tree_row, int i, Settings folder_settings) {
        if (tree_row == null) {
            return;
        }

        if (tree_row.get_item () is Camel.OfflineStore) {
            tree_row.set_expanded (true);
        }

        if(tree_row.get_child_row (i) != null) {
            expand_saved_folders (tree_row.get_child_row (i), 0, folder_settings);

            var row = tree_row.get_child_row (i);
            var item = tree_row.get_child_row (i).get_item ();

            if (item is Mail.FolderInfo) {
                var folder_item = (Mail.FolderInfo) item;

                if(folder_item.folder_info.full_name in folder_settings.get_strv ("expanded-folders")) {
                    row.set_expanded(true);
                }

                row.notify["expanded"].connect (() => {
                    var folders = folder_settings.get_strv("expanded-folders");
                    if (row.expanded) {
                        folders += folder_item.folder_info.full_name;
                    } else {
                        string[] new_folders = {};
                        foreach (var folder in folders) {
                            if (folder != folder_item.folder_info.full_name) {
                                new_folders += folder;
                            }
                        }
                        folders = new_folders;
                    }
                    folder_settings.set_strv("expanded-folders", folders);
                });
            }
            expand_saved_folders (tree_row, i + 1, folder_settings);
        }
    }

    public void refresh_folder_info (Camel.OfflineStore offlinestore) {
        offlinestore.get_folder_info.begin (null, Camel.StoreGetFolderInfoFlags.FAST, Priority.DEFAULT, null, (obj, res) => {
            try {
                var new_folder_info = offlinestore.get_folder_info.end (res);
                folder_info_per_account[offlinestore.uid] = new Mail.FolderInfo (offlinestore, new_folder_info);
            } catch (Error e) {
                critical ("Unable to refresh folder information for account %s: %s", offlinestore.display_name, e.message);
            }
        });
    }
}
