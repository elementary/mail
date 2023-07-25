/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2017-2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

public class Mail.FolderRow : Gtk.ListBoxRow {
   public int depth { get; construct; } //Currently not used
   public Camel.FolderInfo folder_info { get; construct; }
   public Camel.Store store { get; construct; }
   public int pos { get; construct; }

   public FolderRow (int depth, Camel.FolderInfo folder_info, Camel.Store store) {
       Object (depth: depth, folder_info: folder_info, store: store);
   }

   construct {
       var icon = new Gtk.Image.from_icon_name ("folder", MENU) {
           margin_end = 3
       };

       var full_folder_info_flags = Utils.get_full_folder_info_flags (store, folder_info);
       switch (full_folder_info_flags & Camel.FOLDER_TYPE_MASK) {
           case Camel.FolderInfoFlags.TYPE_INBOX:
               icon.set_from_icon_name ("mail-inbox", MENU);
               pos = 1;
               break;
           case Camel.FolderInfoFlags.TYPE_DRAFTS:
               icon.set_from_icon_name ("mail-drafts", MENU);
               pos = 2;
               break;
           case Camel.FolderInfoFlags.TYPE_OUTBOX:
               icon.set_from_icon_name ("mail-outbox", MENU);
               pos = 3;
               break;
           case Camel.FolderInfoFlags.TYPE_SENT:
               icon.set_from_icon_name ("mail-sent", MENU);
               pos = 4;
               break;
           case Camel.FolderInfoFlags.TYPE_ARCHIVE:
               icon.set_from_icon_name ("mail-archive", MENU);
               pos = 5;
               break;
           case Camel.FolderInfoFlags.TYPE_TRASH:
               icon.set_from_icon_name (folder_info.total == 0 ? "user-trash" : "user-trash-full", MENU);
               pos = 6;
               break;
           case Camel.FolderInfoFlags.TYPE_JUNK:
               icon.set_from_icon_name ("edit-flag", MENU);
               pos = 7;
               break;
           default:
               icon.set_from_icon_name ("folder", MENU);
               pos = 8;
               break;
       }

       var box = new Gtk.Box (HORIZONTAL, 0) {
           margin_top = 6,
           margin_bottom = 6,
           margin_start = 12,
           margin_end = 12
       };

       box.add (icon);
       box.add (new Gtk.Label (folder_info.display_name));

       child = box;
       show_all ();
   }
}
