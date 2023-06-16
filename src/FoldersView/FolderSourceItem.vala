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

    public string full_name;
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

        editable = true;
        edited.connect (rename);
    }

    ~FolderSourceItem () {
        cancellable.cancel ();
    }

    public override Gtk.Menu? get_context_menu () {
        var rename_item = new Gtk.MenuItem.with_label (_("Rename folder"));
        var refresh_item = new Gtk.MenuItem.with_label (_("Refresh folder"));

        var menu = new Gtk.Menu ();
        menu.add (rename_item);
        menu.add (new Gtk.SeparatorMenuItem ());
        menu.add (refresh_item);
        menu.show_all ();

        rename_item.activate.connect (() => start_edit ());
        refresh_item.activate.connect (() => refresh.begin ());
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
                break;
            case Camel.FolderInfoFlags.TYPE_OUTBOX:
                icon = new ThemedIcon ("mail-outbox");
                can_modify = false;
                break;
            case Camel.FolderInfoFlags.TYPE_TRASH:
                icon = new ThemedIcon (folderinfo.total == 0 ? "user-trash" : "user-trash-full");
                can_modify = false;
                badge = null;
                break;
            case Camel.FolderInfoFlags.TYPE_JUNK:
                icon = new ThemedIcon ("edit-flag");
                can_modify = false;
                break;
            case Camel.FolderInfoFlags.TYPE_SENT:
                icon = new ThemedIcon ("mail-sent");
                can_modify = false;
                break;
            case Camel.FolderInfoFlags.TYPE_ARCHIVE:
                icon = new ThemedIcon ("mail-archive");
                can_modify = false;
                badge = null;
                break;
            case Camel.FolderInfoFlags.TYPE_DRAFTS:
                icon = new ThemedIcon ("mail-drafts");
                can_modify = false;
                break;
            default:
                icon = new ThemedIcon ("folder");
                can_modify = true;
                break;
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

    private async void rename (string new_name) {
        var offlinestore = (Camel.Store) account.service;
        try {
            yield offlinestore.rename_folder (name, new_name, GLib.Priority.DEFAULT, cancellable);
        } catch (Error e) {
            warning ("Unable to rename folder '%s': %s", old_name, e.message);
            name = old_name;

            MainWindow? main_window = null;
            foreach (unowned var window in ((Application)GLib.Application.get_default ()).get_windows ()) {
                if (window is MainWindow) {
                    main_window = (MainWindow) window;
                    main_window.send_error_toast (_("Unable to rename folder '%s': %s").printf (old_name, e.message));
                    break;
                }
            }
        }
    }
}
