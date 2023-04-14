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

public class Mail.FolderItemModel : Object {
    public string icon_name { get; construct; }
    public string name { get; construct; }
    public int unread { get; construct; }

    public Mail.Backend.Account account { get; construct; }
    public string full_name { get; construct; }
    public Camel.FolderInfo folder_info { get; construct; }

    public ListStore folder_list;

    public FolderItemModel (Camel.FolderInfo folderinfo, Mail.Backend.Account account) {
        Object (account: account,
            folder_info: folderinfo
        );
    }

    construct {
        name = folder_info.display_name;
        unread = folder_info.unread;
        full_name = folder_info.full_name;

        folder_list = new ListStore (typeof(FolderItemModel));

        if (folder_info.child != null) {
            var current_folder_info = folder_info.child;
            while (current_folder_info != null) {
                var folder_item = new FolderItemModel (current_folder_info, account);
                folder_list.append (folder_item);

                current_folder_info = (Camel.FolderInfo?) current_folder_info.next;
            }
        }

        var full_folder_info_flags = Utils.get_full_folder_info_flags (account.service, folder_info);
        switch (full_folder_info_flags & Camel.FOLDER_TYPE_MASK) {
            case Camel.FolderInfoFlags.TYPE_INBOX:
                icon_name = "mail-inbox";
                break;
            case Camel.FolderInfoFlags.TYPE_OUTBOX:
                icon_name = "mail-outbox";
                break;
            case Camel.FolderInfoFlags.TYPE_TRASH:
                icon_name = folder_info.total == 0 ? "user-trash" : "user-trash-full";
                break;
            case Camel.FolderInfoFlags.TYPE_JUNK:
                icon_name = "edit-flag";
                break;
            case Camel.FolderInfoFlags.TYPE_SENT:
                icon_name = "mail-sent";
                break;
            case Camel.FolderInfoFlags.TYPE_ARCHIVE:
                icon_name = "mail-archive";
                break;
            case Camel.FolderInfoFlags.TYPE_DRAFTS:
                icon_name = "mail-drafts";
                break;
            default:
                icon_name = "folder";
                break;
        }
    }
}

