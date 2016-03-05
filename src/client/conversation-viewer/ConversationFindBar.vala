// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016 elementary LLC.
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class ConversationFindBar : Gtk.Revealer {
    Gtk.ListBox mail_list_box;

    Gtk.SearchEntry search_entry;
    Gtk.ToolButton previous_button;
    Gtk.ToolButton next_button;
    Gtk.CheckButton case_check;
    Gtk.Label answer_label;

    public ConversationFindBar (Gtk.ListBox mail_list_box) {
        this.mail_list_box = mail_list_box;
    }

    construct {
        var close_button = new Gtk.ToolButton (null, null);
        close_button.icon_name = "close-symbolic";

        search_entry = new Gtk.SearchEntry ();
        search_entry.margin_start = 6;
        var search_item = new Gtk.ToolItem ();
        search_item.valign = Gtk.Align.CENTER;
        search_item.add (search_entry);

        previous_button = new Gtk.ToolButton (null, null);
        previous_button.icon_name = "go-up-symbolic";

        next_button = new Gtk.ToolButton (null, null);
        next_button.icon_name = "go-down-symbolic";

        case_check = new Gtk.CheckButton.with_label (_("Case sensitive"));
        var case_item = new Gtk.ToolItem ();
        case_item.add (case_check);

        var expand_item = new Gtk.SeparatorToolItem ();
        expand_item.draw = false;

        answer_label = new Gtk.Label (null);
        answer_label.margin_start = 6;
        answer_label.margin_end = 6;
        var answer_item = new Gtk.ToolItem ();
        answer_item.add (answer_label);

        var toolbar = new Gtk.Toolbar ();
        toolbar.get_style_context ().add_class ("search-bar");
        toolbar.icon_size = Gtk.IconSize.SMALL_TOOLBAR;
        toolbar.add (close_button);
        toolbar.add (search_item);
        toolbar.add (previous_button);
        toolbar.add (next_button);
        toolbar.add (case_item);
        toolbar.add (expand_item);
        toolbar.child_set_property (expand_item, "expand", true);
        toolbar.add (answer_item);

        add (toolbar);
        close_button.clicked.connect (() => reveal (false));
    }

    public void reveal (bool do_reveal) {
        set_reveal_child (do_reveal);
        if (do_reveal) {
            search_entry.grab_focus ();
            mark_text_matches ();
        } else {
            unmark_text_matches ();
        }
    }

    public void find (bool next) {
        if (search_entry.text.strip () == "") {
            return;
        }

        mail_list_box.get_children ().foreach ((child) => {
            if (!(child is ConversationWidget)) {
                return;
            }

            //var webview = ((ConversationWidget) child).webview;
        });
    }

    private void mark_text_matches () {
        var search = search_entry.text.strip ();
        if (search == "") {
            return;
        }

        uint matches = 0U;
        mail_list_box.get_children ().foreach ((child) => {
            if (!(child is ConversationWidget)) {
                return;
            }

            var webview = ((ConversationWidget) child).webview;
            matches += webview.mark_text_matches (search, case_check.active, 0);
            webview.set_highlight_text_matches (true);
        });
        
        if (matches == 0) {
            answer_label.label = _("not found");
        } else {
            answer_label.label = ngettext ("%u match", "%u matches", matches).printf (matches);
        }
    }

    private void unmark_text_matches () {
        mail_list_box.get_children ().foreach ((child) => {
            if (!(child is ConversationWidget)) {
                return;
            }

            var webview = ((ConversationWidget) child).webview;
            webview.unmark_text_matches ();
        });
    }
}
