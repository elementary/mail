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
    public signal void refresh ();

    public string full_name { get; private set; }
    public bool is_special_folder { get; private set; default = true; }
    public int pos { get; private set; }
    public Backend.Account account { get; construct; }

    private bool can_modify = true;

    public FolderSourceItem (Backend.Account account, Camel.FolderInfo folderinfo) {
        Object (account: account);
        update_infos (folderinfo);
    }

    public override Gtk.Menu? get_context_menu () {
        var menu = new Gtk.Menu ();
        var refresh_item = new Gtk.MenuItem.with_label (_("Refresh folder"));
        menu.add (refresh_item);
        menu.show_all ();

        refresh_item.activate.connect (() => refresh ());
        return menu;
    }

    public void update_infos (Camel.FolderInfo folderinfo) {
        name = folderinfo.display_name;
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
    }
}
