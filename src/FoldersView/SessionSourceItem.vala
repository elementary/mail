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

 public class Mail.SessionSourceItem : Granite.Widgets.SourceList.ExpandableItem {
    public Mail.Backend.Session session { get; construct; }

    public SessionSourceItem (Mail.Backend.Session session) {
        Object (session: session);
    }

    construct {
        name = _("All Mailboxes");
        visible = session.get_accounts ().size > 1;
        expanded = true;
        collapsible = false;

        add (new GroupedFolderSourceItem (session, Camel.FolderInfoFlags.TYPE_INBOX));

        session.account_added.connect (added_account);
        session.account_removed.connect (removed_account);
    }

    private void added_account (Mail.Backend.Account account) {
        if (session.get_accounts ().size > 1) {
            visible = true;
        }
    }

    private void removed_account () {
        if (session.get_accounts ().size < 2) {
            visible = false;
        }
    }
}
