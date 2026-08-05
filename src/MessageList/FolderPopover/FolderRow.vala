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
       var icon = new Gtk.Image.from_icon_name ("folder") {
           margin_end = 3
       };

       var full_folder_info_flags = Utils.get_full_folder_info_flags (store, folder_info);
       switch (full_folder_info_flags & Camel.FOLDER_TYPE_MASK) {
           case TYPE_INBOX:
               icon.icon_name = "mail-inbox";
               pos = 1;
               break;
           case TYPE_DRAFTS:
               icon.icon_name = "mail-drafts";
               pos = 2;
               break;
           case TYPE_OUTBOX:
               icon.icon_name = "mail-outbox";
               pos = 3;
               break;
           case TYPE_SENT:
               icon.icon_name = "mail-sent";
               pos = 4;
               break;
           case TYPE_ARCHIVE:
               icon.icon_name = "mail-archive";
               pos = 5;
               break;
           case TYPE_TRASH:
               icon.icon_name = folder_info.total == 0 ? "user-trash" : "user-trash-full";
               pos = 6;
               break;
           case TYPE_JUNK:
               icon.icon_name = "edit-flag";
               pos = 7;
               break;
           default:
               icon.icon_name = "folder";
               pos = 8;
               break;
       }

       var box = new Gtk.Box (HORIZONTAL, 0) {
           margin_top = 6,
           margin_bottom = 6,
           margin_start = 12,
           margin_end = 12
       };

       box.append (icon);
       box.append (new Gtk.Label (folder_info.display_name));

       child = box;
   }
}
