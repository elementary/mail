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

public class Mail.FolderSourceItem : Mail.SourceList.ExpandableItem {
    public signal void start_edit ();

    public string full_name { get; private set; }
    public bool is_special_folder { get; private set; default = true; }
    public int pos { get; private set; }
    public Backend.Account account { get; construct; }

    private bool can_modify = true;
    private Cancellable cancellable;
    private string old_name;

    public FolderSourceItem (Backend.Account account, Camel.FolderInfo folderinfo) {
        Object (account: account);
        update_infos (folderinfo);
    }

    construct {
        cancellable = new GLib.Cancellable ();
    }

    ~FolderSourceItem () {
        cancellable.cancel ();
    }

    public override Gtk.Menu? get_context_menu () {
        var menu = new Gtk.Menu ();

        var refresh_item = new Gtk.MenuItem.with_label (_("Refresh folder"));
        refresh_item.activate.connect (() => refresh.begin ());
        menu.add (refresh_item);

        if (!is_special_folder) {
            var rename_item = new Gtk.MenuItem.with_label (_("Rename folder"));
            rename_item.activate.connect (() => start_edit ());
            menu.add (new Gtk.SeparatorMenuItem ());
            menu.add (rename_item);
        }

        menu.show_all ();

        return menu;
    }

    public void update_infos (Camel.FolderInfo folderinfo) {
        name = old_name = folderinfo.display_name;
        full_name = folderinfo.full_name;
        if (folderinfo.unread > 0) {
            badge = "%d".printf (folderinfo.unread);
        }

        var full_folder_info_flags = Utils.get_full_folder_info_flags (account.service, folderinfo);
        switch (full_folder_info_flags & Camel.FOLDER_TYPE_MASK) {
            case Camel.FolderInfoFlags.TYPE_INBOX:
                icon = new ThemedIcon ("mail-inbox");
                can_modify = false;
                pos = 1;
                break;
            case Camel.FolderInfoFlags.TYPE_DRAFTS:
                icon = new ThemedIcon ("mail-drafts");
                can_modify = false;
                pos = 2;
                break;
            case Camel.FolderInfoFlags.TYPE_OUTBOX:
                icon = new ThemedIcon ("mail-outbox");
                can_modify = false;
                pos = 3;
                break;
            case Camel.FolderInfoFlags.TYPE_SENT:
                icon = new ThemedIcon ("mail-sent");
                can_modify = false;
                pos = 4;
                break;
            case Camel.FolderInfoFlags.TYPE_ARCHIVE:
                icon = new ThemedIcon ("mail-archive");
                can_modify = false;
                pos = 5;
                badge = null;
                break;
            case Camel.FolderInfoFlags.TYPE_TRASH:
                icon = new ThemedIcon (folderinfo.total == 0 ? "user-trash" : "user-trash-full");
                can_modify = false;
                pos = 6;
                badge = null;
                break;
            case Camel.FolderInfoFlags.TYPE_JUNK:
                icon = new ThemedIcon ("edit-flag");
                can_modify = false;
                pos = 7;
                break;
            default:
                icon = new ThemedIcon ("folder");
                can_modify = true;
                pos = 8;
                is_special_folder = false;
                break;
        }

        if (!is_special_folder && editable != true) {
            editable = true;
            edited.connect (rename);
        } else if (is_special_folder) {
            editable = false;
            edited.disconnect (rename);
        }
    }

    private async void refresh () {
        var offlinestore = (Camel.Store)account.service;
        try {
            var folder = yield offlinestore.get_folder (full_name, 0, GLib.Priority.DEFAULT, cancellable);
            yield folder.refresh_info (GLib.Priority.DEFAULT, cancellable);
        } catch (Error e) {
            critical (e.message);
        }
    }

    private void cancel_rename () {
        name = old_name;
        notify["name"].disconnect (cancel_rename);
    }

    private async void rename (string new_name) {
        if (new_name == old_name) {
            return;
        }

        if ("/" in new_name) {
            if (name == old_name) {
                notify["name"].connect (cancel_rename);
            } else {
                cancel_rename ();
            }

            MainWindow.send_error_message (
                _("Couldn't rename “%s”").printf (name),
                _("Folder names cannot contain “/”"),
                "folder"
            );

            return;
        }

        string[] split_full_name = full_name.split_set ("/");
        split_full_name[split_full_name.length - 1] = new_name;
        var new_full_name = string.joinv ("/", split_full_name);

        var offlinestore = (Camel.Store)account.service;

        Camel.FolderInfo? folder_info = null;
        try {
            folder_info = yield offlinestore.get_folder_info (new_full_name, FAST, GLib.Priority.DEFAULT, cancellable);
        } catch (Error e) {
            warning (e.message);
        }

        if (null != folder_info) {
            if (name == old_name) {
                notify["name"].connect (cancel_rename);
            } else {
                cancel_rename ();
            }

            MainWindow.send_error_message (
                _("Couldn't rename “%s”").printf (name),
                _("A folder named “%s” already exists").printf (new_name),
                "folder"
            );

            return;
        }

        try {
            yield offlinestore.rename_folder (full_name, new_full_name, GLib.Priority.DEFAULT, cancellable);
        } catch (Error e) {
            if (name == old_name) {
                notify["name"].connect (cancel_rename);
            } else {
                cancel_rename ();
            }

            MainWindow.send_error_message (
                _("Couldn't rename “%s”").printf (name),
                e.message,
                "folder"
            );
        }
    }
}
