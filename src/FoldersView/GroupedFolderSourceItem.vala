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

public class Mail.GroupedFolderSourceItem : Granite.Widgets.SourceList.Item {
    public Mail.Backend.Session session { get; construct; }
    public string full_name;

    private GLib.Cancellable connect_cancellable;
    private Gee.HashMap<Backend.Account, Camel.FolderInfo?> account_folderinfo;

    public GroupedFolderSourceItem (Mail.Backend.Session session) {
        Object (session: session);
    }

    construct {
        visible = true;
        connect_cancellable = new GLib.Cancellable ();
        account_folderinfo = new Gee.HashMap<Backend.Account, Camel.FolderInfo?> ();

        name = _("Inbox");
        full_name = "INBOX";
        icon = new ThemedIcon ("mail-inbox");

        session.get_accounts ().foreach ((account) => {
            add_account (account);
            return true;
        });

        session.account_added.connect (add_account);
        session.account_removed.connect (removed_account);
    }

    ~GroupedFolderSourceItem () {
        connect_cancellable.cancel ();
    }

    public Backend.Account[] get_accounts () {
        return account_folderinfo.keys.read_only_view.to_array ();
    }

    private void add_account (Mail.Backend.Account account) {
        lock (account_folderinfo) {
            account_folderinfo.set (account, null);
        }
        load_folder_info.begin (account);
    }

    private async void load_folder_info (Mail.Backend.Account account) {
        var offlinestore = (Camel.OfflineStore) account.service;
        Camel.FolderInfo? folderinfo = null;

        try {
            folderinfo = yield offlinestore.get_folder_info (full_name, 0, GLib.Priority.DEFAULT, connect_cancellable);

        } catch (Error e) {
            // We can cancel the operation
            if (!(e is GLib.IOError.CANCELLED)) {
                warning ("Unable to fetch %s of account '%s': %s", full_name, account.service.display_name, e.message);
            }
        }

        lock (account_folderinfo) {
            account_folderinfo.set (account, folderinfo);
        }
        update_infos ();
    }

    private void removed_account () {
        var accounts_left = session.get_accounts ();

        foreach (var account in account_folderinfo.keys) {
            if (!accounts_left.contains (account)) {
                lock (account_folderinfo) {
                    account_folderinfo.unset (account);
                }
            }
        }
    }

    private void update_infos () {
        badge = null;
        var total_unread = 0;
        lock (account_folderinfo) {
            foreach (var entry in account_folderinfo) {
                if (entry.value == null) {
                    continue;
                }
                total_unread += entry.value.unread;
            }
        }
        if (total_unread > 0) {
            badge = "%d".printf (total_unread);
        }
    }
}
