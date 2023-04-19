/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

 public class Mail.SessionItemModel : ItemModel {
    public const string account = "SESSION ACCOUNT";

    construct {
        name = _("All Mailboxes");
        icon_name = "go-home";
        account_uid = account_uid;

        folder_list = new ListStore (typeof(GroupedFolderItemModel));
        folder_list.append (new GroupedFolderItemModel (Camel.FolderInfoFlags.TYPE_INBOX));
        folder_list.append (new GroupedFolderItemModel (Camel.FolderInfoFlags.TYPE_ARCHIVE));
        folder_list.append (new GroupedFolderItemModel (Camel.FolderInfoFlags.TYPE_SENT));
    }

    public void add_account (Mail.Backend.Account account) {
        for (int i = 0; folder_list.get_item (i) != null; i++) {
            var item = (GroupedFolderItemModel)folder_list.get_item (i);
            item.add_account (account);
        }
    }

    public void remove_account (Mail.Backend.Account account) {
        for (int i = 0; folder_list.get_item (i) != null; i++) {
            var item = (GroupedFolderItemModel)folder_list.get_item (i);
            item.remove_account (account);
        }
    }
}
