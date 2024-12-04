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

public class Mail.MainWindow : Hdy.ApplicationWindow {
    private Gtk.Paned paned_end;
    private Gtk.Paned paned_start;

    private FoldersListView folders_list_view;
    private Granite.Widgets.Toast move_toast;
    private Granite.Widgets.Toast error_toast;
    private ConversationList conversation_list;
    private MessageList message_list;

    private uint configure_id;

    public bool is_session_started { get; private set; default = false; }
    public signal void session_started ();

    public const string ACTION_GROUP_PREFIX = "win";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    public const string ACTION_COMPOSE_MESSAGE = "compose_message";
    public const string ACTION_REFRESH = "refresh";
    public const string ACTION_REPLY = "reply";
    public const string ACTION_REPLY_ALL = "reply-all";
    public const string ACTION_FORWARD = "forward";
    public const string ACTION_PRINT = "print";
    public const string ACTION_MODIFY = "modify";
    public const string ACTION_MARK_READ = "mark-read";
    public const string ACTION_MARK_STAR = "mark-star";
    public const string ACTION_MARK_UNREAD = "mark-unread";
    public const string ACTION_MARK_UNSTAR = "mark-unstar";
    public const string ACTION_ARCHIVE = "archive";
    public const string ACTION_MOVE = "move";
    public const string ACTION_MOVE_TO_TRASH = "trash";
    public const string ACTION_FULLSCREEN = "full-screen";

    public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

    private const ActionEntry[] ACTION_ENTRIES = {
        {ACTION_COMPOSE_MESSAGE, action_compose },
        {ACTION_REFRESH, on_refresh },
        {ACTION_REPLY, action_compose, "s" },
        {ACTION_REPLY_ALL, action_compose, "s" },
        {ACTION_FORWARD, action_compose, "s" },
        {ACTION_PRINT, on_print, "s" },
        {ACTION_MODIFY, null }, // Stores enabled state only
        {ACTION_MARK_READ, on_mark_read },
        {ACTION_MARK_STAR, on_mark_star },
        {ACTION_MARK_UNREAD, on_mark_unread },
        {ACTION_MARK_UNSTAR, on_mark_unstar },
        {ACTION_ARCHIVE, action_move },
        {ACTION_MOVE, action_move, "s" },
        {ACTION_MOVE_TO_TRASH, action_move },
        {ACTION_FULLSCREEN, on_fullscreen },
    };

    public MainWindow (Gtk.Application application) {
        Object (
            application: application,
            height_request: 600,
            icon_name: "io.elementary.mail",
            width_request: 800,
            title: _("Mail")
        );
    }

    static construct {
        action_accelerators[ACTION_COMPOSE_MESSAGE] = "<Control>N";
        action_accelerators[ACTION_REFRESH] = "F12";
        action_accelerators[ACTION_REPLY + "::"] = "<Control>R";
        action_accelerators[ACTION_REPLY_ALL + "::"] = "<Control><Shift>R";
        action_accelerators[ACTION_FORWARD + "::"] = "<Ctrl><Shift>F";
        action_accelerators[ACTION_MARK_READ] = "<Ctrl><Shift>i";
        action_accelerators[ACTION_MARK_STAR] = "<Ctrl>l";
        action_accelerators[ACTION_MARK_UNREAD] = "<Ctrl><Shift>u";
        action_accelerators[ACTION_MARK_UNSTAR] = "<Ctrl><Shift>l";
        action_accelerators[ACTION_ARCHIVE] = "<Ctrl><Shift>a";
        action_accelerators[ACTION_MOVE_TO_TRASH] = "Delete";
        action_accelerators[ACTION_MOVE_TO_TRASH] = "BackSpace";
        action_accelerators[ACTION_FULLSCREEN] = "F11";
    }

    construct {
        add_action_entries (ACTION_ENTRIES, this);
        get_action (ACTION_COMPOSE_MESSAGE).set_enabled (false);

        foreach (var action in action_accelerators.get_keys ()) {
            ((Gtk.Application) GLib.Application.get_default ()).set_accels_for_action (
                ACTION_PREFIX + action,
                action_accelerators[action].to_array ()
            );
        }

        folders_list_view = new FoldersListView ();
        conversation_list = new ConversationList ();

        message_list = new MessageList ();

        var view_overlay = new Gtk.Overlay () {
            hexpand = true,
            vexpand = true,
            child = message_list
        };

        move_toast = new Granite.Widgets.Toast ("");
        move_toast.set_default_action (_("Undo"));
        move_toast.show_all ();
        view_overlay.add_overlay (move_toast);

        move_toast.default_action.connect (() => {
            MoveOperation.undo_last_move ();
        });

        error_toast = new Granite.Widgets.Toast ("");
        error_toast.show_all ();
        view_overlay.add_overlay (error_toast);

        var message_overlay = new Granite.Widgets.OverlayBar (view_overlay);
        message_overlay.no_show_all = true;

        message_list.hovering_over_link.connect ((label, url) => {
            var hover_url = url != null ? GLib.Uri.unescape_string (url) : null;

            if (hover_url == null) {
                message_overlay.hide ();
            } else {
                message_overlay.label = hover_url;
                message_overlay.show ();
            }
        });

        paned_start = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned_start.pack1 (folders_list_view, false, false);
        paned_start.pack2 (conversation_list, true, false);

        paned_end = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned_end.pack1 (paned_start, false, false);
        paned_end.pack2 (view_overlay, true, false);

        var welcome_view = new Mail.WelcomeView ();

        var placeholder_stack = new Gtk.Stack ();
        placeholder_stack.add_named (paned_end, "mail");
        placeholder_stack.add_named (welcome_view, "welcome");

        add (placeholder_stack);

        var header_group = new Hdy.HeaderGroup ();
        header_group.add_header_bar (folders_list_view.header_bar);
        header_group.add_header_bar (conversation_list.search_header);
        header_group.add_header_bar (message_list.headerbar);

        var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.VERTICAL);
        size_group.add_widget (folders_list_view.header_bar);
        size_group.add_widget (conversation_list.search_header);
        size_group.add_widget (message_list.headerbar);

        var settings = new GLib.Settings ("io.elementary.mail");
        settings.bind ("paned-start-position", paned_start, "position", SettingsBindFlags.DEFAULT);
        settings.bind ("paned-end-position", paned_end, "position", SettingsBindFlags.DEFAULT);

        folders_list_view.folder_selected.connect (conversation_list.load_folder);

        conversation_list.conversation_selected.connect (message_list.set_conversation);

        unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();

        var account_removed_handler = session.account_removed.connect (() => {
            var accounts_left = session.get_accounts ();
            if (accounts_left.size == 0) {
                get_action (ACTION_COMPOSE_MESSAGE).set_enabled (false);
            }
        });

        var account_added_handler = session.account_added.connect (() => {
            placeholder_stack.visible_child = paned_end;
            get_action (ACTION_COMPOSE_MESSAGE).set_enabled (true);
        });

        session.start.begin ((obj, res) => {
            session.start.end (res);

            if (session.get_accounts ().size > 0) {
                placeholder_stack.visible_child = paned_end;
                get_action (ACTION_COMPOSE_MESSAGE).set_enabled (true);
            } else {
                placeholder_stack.visible_child = welcome_view;
                placeholder_stack.transition_type = Gtk.StackTransitionType.OVER_DOWN_UP;
            }

            is_session_started = true;
            session_started ();
        });

        delete_event.connect (() => {
            ((Application)application).request_background.begin (() => destroy ());

            return Gdk.EVENT_STOP;
        });

        destroy.connect (() => {
            session.disconnect (account_removed_handler);
            session.disconnect (account_added_handler);
            destroy ();
        });
    }

    private void on_refresh () {
        conversation_list.refresh_folder.begin ();
    }

    private void on_mark_read () {
        conversation_list.mark_read_selected_messages ();
        get_action (ACTION_MARK_READ).set_enabled (false);
        get_action (ACTION_MARK_UNREAD).set_enabled (true);
    }

    private void on_mark_star () {
        conversation_list.mark_star_selected_messages ();
        get_action (ACTION_MARK_STAR).set_enabled (false);
        get_action (ACTION_MARK_UNSTAR).set_enabled (true);
    }

    private void on_mark_unread () {
        conversation_list.mark_unread_selected_messages ();
        get_action (ACTION_MARK_UNREAD).set_enabled (false);
        get_action (ACTION_MARK_READ).set_enabled (true);
    }

    private void on_mark_unstar () {
        conversation_list.mark_unstar_selected_messages ();
        get_action (ACTION_MARK_UNSTAR).set_enabled (false);
        get_action (ACTION_MARK_STAR).set_enabled (true);
    }

    private void action_compose (SimpleAction action, Variant? parameter) {
        switch (action.name) {
            case ACTION_COMPOSE_MESSAGE:
                new Composer ().present ();
                break;
            case ACTION_REPLY:
                message_list.compose.begin (Composer.Type.REPLY, parameter);
                break;
            case ACTION_REPLY_ALL:
                message_list.compose.begin (Composer.Type.REPLY_ALL, parameter);
                break;
            case ACTION_FORWARD:
                message_list.compose.begin (Composer.Type.FORWARD, parameter);
                break;
        }
    }

    private void on_print (SimpleAction action, Variant? parameter) {
        message_list.print (parameter);
    }

    private void action_move (SimpleAction action, Variant? parameter) {
        switch (action.name) {
            case ACTION_ARCHIVE:
                conversation_list.move_selected_messages.begin (MoveOperation.MoveType.ARCHIVE, null, (obj, res) => {
                    string error_message;
                    var result = conversation_list.move_selected_messages.end (res, out error_message);
                    if (result > 0) {
                        move_toast.title = ngettext ("Message Archived", "Messages Archived", result);
                        move_toast.send_notification ();
                    } else if (error_message != "") {
                        send_error_message (
                            _("Couldn't archive message"),
                            error_message,
                            "mail-archive"
                        );
                    }
                });
                break;

            case ACTION_MOVE:
                conversation_list.move_selected_messages.begin (MoveOperation.MoveType.MOVE, parameter, (obj, res) => {
                    string error_message;
                    var result = conversation_list.move_selected_messages.end (res, out error_message);
                    if (result > 0) {
                        move_toast.title = ngettext ("Message Moved", "Messages Moved", result);
                        move_toast.send_notification ();
                    } else if (error_message != "") {
                        send_error_message (
                            _("Couldn't move message"),
                            error_message,
                            "mail-move"
                        );
                    }
                });
                break;

            case ACTION_MOVE_TO_TRASH:
                conversation_list.move_selected_messages.begin (MoveOperation.MoveType.TRASH, null, (obj, res) => {
                    string error_message;
                    var result = conversation_list.move_selected_messages.end (res, out error_message);
                    if (result > 0) {
                        move_toast.title = ngettext ("Message Deleted", "Messages Deleted", result);
                        move_toast.send_notification ();
                    } else if (error_message != "") {
                        send_error_message (
                            _("Couldn't delete message"),
                            error_message,
                            "edit-delete"
                        );
                    }
                });
                break;
        }
    }

    private void on_fullscreen () {
        if (Gdk.WindowState.FULLSCREEN in get_window ().get_state ()) {
            message_list.headerbar.show_close_button = true;
            unfullscreen ();
        } else {
            message_list.headerbar.show_close_button = false;
            fullscreen ();
        }
    }

    private SimpleAction? get_action (string name) {
        return (SimpleAction) lookup_action (name);
    }

    public static void send_error_message (string title, string description, string? icon_name = null, string? error_details = null) {
        var dialog = new Granite.MessageDialog (
            title,
            description,
            new ThemedIcon ("dialog-error")
        ) {
            modal = true,
            transient_for = ((Gtk.Application) GLib.Application.get_default ()).active_window
        };

        if (icon_name != null) {
            dialog.image_icon = new ThemedIcon (icon_name);
            dialog.badge_icon = new ThemedIcon ("dialog-error");
        }

        if (error_details != null) {
            dialog.show_error_details (error_details);
        }

        dialog.present ();
        dialog.response.connect (dialog.destroy);
    }

    public override bool configure_event (Gdk.EventConfigure event) {
        if (configure_id != 0) {
            GLib.Source.remove (configure_id);
        }

        configure_id = Timeout.add (100, () => {
            configure_id = 0;

            if (is_maximized) {
                Mail.Application.settings.set_boolean ("window-maximized", true);
            } else {
                Mail.Application.settings.set_boolean ("window-maximized", false);

                Gdk.Rectangle rect;
                get_allocation (out rect);
                Mail.Application.settings.set ("window-size", "(ii)", rect.width, rect.height);
            }

            return false;
        });

        return base.configure_event (event);
    }
}
