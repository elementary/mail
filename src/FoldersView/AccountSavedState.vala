// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.AccountSavedState : GLib.Object {
    public unowned Mail.Backend.Account account { get; construct; }

    private GLib.Settings settings;
    private Gee.HashMap<string, FolderSourceItem> items;

    public AccountSavedState (Mail.Backend.Account account) {
        Object (account: account);
    }

    construct {
        settings = new GLib.Settings.with_path ("io.elementary.mail.accounts", "/io/elementary/mail/accounts/%s/".printf (account.service.uid));
        items = new Gee.HashMap<string, FolderSourceItem> ();
    }

    public void bind_with_expandable_item (Granite.Widgets.SourceList.ExpandableItem item) {
        if (item is AccountSourceItem) {
            settings.bind ("expanded", item, "expanded", SettingsBindFlags.DEFAULT | SettingsBindFlags.GET_NO_CHANGES);
        } else if (item is FolderSourceItem) {
            var folder_item = (FolderSourceItem) item;
            items[folder_item.full_name] = folder_item;
            if (folder_item.full_name in settings.get_strv ("expanded-folders")) {
                item.expanded = true;
            }

            item.notify["expanded"].connect (() => {
                var folders = settings.get_strv ("expanded-folders");
                if (item.expanded) {
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

                settings.set_strv ("expanded-folders", folders);
            });
        }
    }
}
