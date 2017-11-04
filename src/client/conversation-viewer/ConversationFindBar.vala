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
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
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

    unowned WebKit.WebView latest_view = null;

    public ConversationFindBar (Gtk.ListBox mail_list_box) {
        this.mail_list_box = mail_list_box;
        mail_list_box.add.connect ((child) => {
            if (!(child is ConversationWidget)) {
                return;
            }

            if (child_revealed) {
                mark_text_matches ();
            }
        });
    }

    construct {
        var close_button = new Gtk.ToolButton (null, null);
        close_button.icon_name = "close-symbolic";

        search_entry = new Gtk.SearchEntry ();
        search_entry.margin_start = 6;
        var search_item = new Gtk.ToolItem ();
        search_item.valign = Gtk.Align.CENTER;
        search_item.add (search_entry);
        search_entry.search_changed.connect (() => mark_text_matches ());
        search_entry.next_match.connect (() => find (true));
        search_entry.previous_match.connect (() => find (false));
        search_entry.activate.connect (() => find (true));

        previous_button = new Gtk.ToolButton (null, null);
        previous_button.icon_name = "go-up-symbolic";
        previous_button.sensitive = false;

        next_button = new Gtk.ToolButton (null, null);
        next_button.icon_name = "go-down-symbolic";
        next_button.sensitive = false;

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
            populate_entry ();
            mark_text_matches ();
        } else {
            unmark_text_matches ();
        }
    }

    public void find (bool next) {
        if (search_entry.text.strip () == "") {
            return;
        }

        // we need the second_start to seach from the beginning
        bool second_start = false;
        int i = next ? 0 : (int)mail_list_box.get_children ().length () - 1;
        for (weak Gtk.Widget child = mail_list_box.get_row_at_index (i); child != null; child = mail_list_box.get_row_at_index (i)) {
            var conv_widget = (ConversationWidget) child;
            var webview = conv_widget.webview;
            if (latest_view == null || latest_view == webview) {
                var found = webview.search_text (search_entry.text, case_check.active, next, false);
                if (found) {
                    // expand the view so that the result is shown.
                    conv_widget.collapsed = false;
                    latest_view = webview;
                    return;
                } else {
                    latest_view = null;
                }
            }

            if (next) {
                i++;
            } else {
                i--;
            }

            if (mail_list_box.get_row_at_index (i) == null && !second_start) {
                i = next ? 0 : (int)mail_list_box.get_children ().length () - 1;
                second_start = true;
            }
        }
    }

    private void populate_entry () {
        mail_list_box.get_children ().foreach ((child) => {
            if (!(child is ConversationWidget)) {
                return;
            }

            var webview = ((ConversationWidget) child).webview;
            var selection = webview.get_dom_document ().default_view.get_selection ();
            if (selection.get_range_count () <= 0)
                return;

            try {
                WebKit.DOM.Range range = selection.get_range_at (0);
                if (range.get_text ().strip () != "") {
                    search_entry.text = range.get_text ();
                }
            } catch (Error e) {
                warning ("Could not get selected text from web view: %s", e.message);
            }
        });
    
    }

    private void mark_text_matches () {
        var search = search_entry.text.strip ();
        if (search == "") {
            unmark_text_matches ();
            next_button.sensitive = false;
            previous_button.sensitive = false;
            search_entry.get_style_context ().remove_class ("error");
            return;
        }

        latest_view = null;
        uint matches = 0U;
        mail_list_box.get_children ().foreach ((child) => {
            if (!(child is ConversationWidget)) {
                return;
            }

            var webview = ((ConversationWidget) child).webview;
            webview.unmark_text_matches ();
            matches += webview.mark_text_matches (search, case_check.active, 0);
            webview.set_highlight_text_matches (true);
        });

        previous_button.sensitive = false;
        if (matches == 0) {
            search_entry.get_style_context ().add_class ("error");
            answer_label.label = _("not found");
            next_button.sensitive = false;
        } else {
            search_entry.get_style_context ().remove_class ("error");
            answer_label.label = ngettext ("%u match", "%u matches", matches).printf (matches);
            next_button.sensitive = true;
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
