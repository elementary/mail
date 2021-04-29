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
    private GLib.SList<Backend.Account> accounts;

    public GroupedFolderSourceItem (Mail.Backend.Session session) {
        Object (session: session);
    }

    construct {
        visible = false;
        connect_cancellable = new GLib.Cancellable ();
        accounts = new GLib.SList<Backend.Account> ();

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
        var accounts = new Backend.Account[this.accounts.length ()];

        for (var i = 0; i < this.accounts.length (); i++) {
            accounts[i] = this.accounts.nth_data (i);
        }
        return accounts;
    }

    private void add_account (Mail.Backend.Account account) {
        accounts.append (account);
        if (accounts.length () > 1) {
            visible = true;
        }
    }

    private void removed_account () {
        var accounts_left = session.get_accounts ();

        for (var i = 0; i < accounts.length (); i++) {
            var account = accounts.nth_data (i);

            if (accounts_left.index_of (account) == -1) {
                accounts.remove (account);
                i = 0;
            }
        }

        if (accounts.length () < 2) {
            visible = false;
        }
    }
}