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

public class Mail.MainWindow : Gtk.Window {
    private HeaderBar headerbar;
    private Gtk.Paned paned_end;
    private Gtk.Paned paned_start;
    
    private FoldersListView folders_list_view;
    private ConversationListBox conversation_list_box;
    private MessageListBox message_list_box;
    private Gtk.ScrolledWindow message_list_scrolled;

    private SimpleActionGroup actions;

    public const string ACTION_COMPOSE_MESSAGE = "compose_message";
    public const string ACTION_REPLY = "reply";

    private const ActionEntry[] action_entries = {
        {ACTION_COMPOSE_MESSAGE,    on_compose_message   },
        {ACTION_REPLY,              on_reply             }
    };

    public MainWindow () {
        Object (
            height_request: 640,
            icon_name: "internet-mail",
            width_request: 910
        );
    }

    construct {
        actions = new SimpleActionGroup ();
        actions.add_action_entries (action_entries, this);
        insert_action_group ("win", actions);

        get_action (ACTION_REPLY).set_enabled (false);

        headerbar = new HeaderBar ();
        set_titlebar (headerbar);

        folders_list_view = new FoldersListView ();
        conversation_list_box = new ConversationListBox ();
        message_list_box = new MessageListBox ();

        var conversation_list_scrolled = new Gtk.ScrolledWindow (null, null);
        conversation_list_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        conversation_list_scrolled.width_request = 158;
        conversation_list_scrolled.add (conversation_list_box);

        message_list_scrolled = new Gtk.ScrolledWindow (null, null);
        message_list_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        message_list_scrolled.add (message_list_box);
        // Prevent the focus of the webview causing the ScrolledWindow to scroll
        var scrolled_child = message_list_scrolled.get_child ();
        if (scrolled_child is Gtk.Container) {
            ((Gtk.Container) scrolled_child).set_focus_vadjustment (new Gtk.Adjustment (0, 0, 0, 0, 0, 0));
        }

        var view_overlay = new Gtk.Overlay();
        view_overlay.add (message_list_scrolled);
        var message_overlay = new Granite.Widgets.OverlayBar (view_overlay);
        message_overlay.no_show_all = true;
        message_list_box.hovering_over_link.connect ((label, url) => {
            var hover_url = url != null ? Soup.URI.decode (url) : null;

            if (hover_url == null) {
                message_overlay.hide ();
            } else {
                message_overlay.status = hover_url;
                message_overlay.show ();
            }
        });

        paned_start = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned_start.pack1 (folders_list_view, false, false);
        paned_start.pack2 (conversation_list_scrolled, true, false);

        paned_end = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned_end.pack1 (paned_start, false, false);
        paned_end.pack2 (view_overlay, true, true);

        add (paned_end);

        var settings = new GLib.Settings ("io.elementary.mail");
        settings.bind ("paned-start-position", paned_start, "position", SettingsBindFlags.DEFAULT);
        settings.bind ("paned-end-position", paned_end, "position", SettingsBindFlags.DEFAULT);

        destroy.connect (() => destroy ());

        folders_list_view.folder_selected.connect ((account, folder_name) => {
            conversation_list_box.set_folder.begin (account, folder_name);
        });

        conversation_list_box.conversation_selected.connect ((node) => {
            message_list_box.set_conversation (node);
            get_action (ACTION_REPLY).set_enabled (true);
        });

        headerbar.size_allocate.connect (() => {
            headerbar.set_paned_positions (paned_start.position, paned_end.position);
        });

        paned_end.notify["position"].connect (() => {
            headerbar.set_paned_positions (paned_start.position, paned_end.position, false);
        });

        paned_start.notify["position"].connect (() => {
            headerbar.set_paned_positions (paned_start.position, paned_end.position);
        });

        Backend.Session.get_default ().start.begin ();
    }

    private void on_compose_message () {
        new ComposerWindow (this).show_all ();
    }

    private void on_reply () {
        message_list_box.reply ();
        message_list_scrolled.get_vadjustment ().set_value (0);
    }

    private SimpleAction? get_action (string name) {
        return actions.lookup_action (name) as SimpleAction;
    }
}
