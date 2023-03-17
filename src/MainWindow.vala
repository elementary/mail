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

public class Mail.MainWindow : Adw.ApplicationWindow {
   // private HeaderBar headerbar;
    private Gtk.SearchEntry search_entry;
    private Gtk.Paned paned_end;
    private Gtk.Paned paned_start;

    private FoldersListView folders_list_view;
    private Gtk.Overlay view_overlay;
    private ConversationListBox conversation_list_box;
//    private MessageListBox message_list_box;
    private Granite.SwitchModelButton hide_read_switch;
    private Granite.SwitchModelButton hide_unstarred_switch;
    private Gtk.Button refresh_button;
    private Gtk.MenuButton filter_button;
    private Gtk.ScrolledWindow message_list_scrolled;
    private Gtk.Spinner refresh_spinner;
    private Gtk.Stack refresh_stack;

    private uint configure_id;
    private uint search_changed_debounce_timeout_id = 0;

    public bool is_session_started { get; private set; default = false; }
    public signal void session_started ();

    public const string ACTION_GROUP_PREFIX = "win";
    public const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    public const string ACTION_COMPOSE_MESSAGE = "compose_message";
    public const string ACTION_REFRESH = "refresh";
    public const string ACTION_REPLY = "reply";
    public const string ACTION_REPLY_ALL = "reply-all";
    public const string ACTION_FORWARD = "forward";
    public const string ACTION_MARK_READ = "mark-read";
    public const string ACTION_MARK_STAR = "mark-star";
    public const string ACTION_MARK_UNREAD = "mark-unread";
    public const string ACTION_MARK_UNSTAR = "mark-unstar";
    public const string ACTION_ARCHIVE = "archive";
    public const string ACTION_MOVE_TO_TRASH = "trash";
    public const string ACTION_FULLSCREEN = "full-screen";

    private static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

    private const ActionEntry[] ACTION_ENTRIES = {
        {ACTION_COMPOSE_MESSAGE, on_compose_message },
        {ACTION_REFRESH, on_refresh },
        {ACTION_REPLY, on_reply },
        {ACTION_REPLY_ALL, on_reply_all },
        {ACTION_FORWARD, on_forward },
        {ACTION_MARK_READ, on_mark_read },
        {ACTION_MARK_STAR, on_mark_star },
        {ACTION_MARK_UNREAD, on_mark_unread },
        {ACTION_MARK_UNSTAR, on_mark_unstar },
        {ACTION_ARCHIVE, on_archive },
        {ACTION_MOVE_TO_TRASH, on_move_to_trash },
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
        action_accelerators[ACTION_REPLY] = "<Control>R";
        action_accelerators[ACTION_REPLY_ALL] = "<Control><Shift>R";
        action_accelerators[ACTION_FORWARD] = "<Ctrl><Shift>F";
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
        //To Do: Look at how other application handle action entries need an actionMap?
        //append_action_entries (ACTION_ENTRIES, this);
        //get_action (ACTION_COMPOSE_MESSAGE).set_enabled (false);

        foreach (var action in action_accelerators.get_keys ()) {
            ((Gtk.Application) GLib.Application.get_default ()).set_accels_for_action (
                ACTION_PREFIX + action,
                action_accelerators[action].to_array ()
            );
        }

        //headerbar = new HeaderBar ();
        //headerbar.add_css_class (Granite.STYLE_CLASS_FLAT);

        folders_list_view = new FoldersListView ();
       conversation_list_box = new ConversationListBox ();

        // Disable delete accelerators when the conversation list box loses keyboard focus,
        // restore them when it returns
        // conversation_list_box.set_focus_child.connect ((widget) => {
        //     if (widget == null) {
        //         ((Gtk.Application) GLib.Application.get_default ()).set_accels_for_action (
        //             ACTION_PREFIX + ACTION_MOVE_TO_TRASH,
        //             {}
        //         );
        //     } else {
        //         ((Gtk.Application) GLib.Application.get_default ()).set_accels_for_action (
        //             ACTION_PREFIX + ACTION_MOVE_TO_TRASH,
        //             action_accelerators[ACTION_MOVE_TO_TRASH].to_array ()
        //         );
        //     }
        // });

        // message_list_box = new MessageListBox ();
        // message_list_box.bind_property ("can-reply", get_action (ACTION_REPLY), "enabled", BindingFlags.SYNC_CREATE);
        // message_list_box.bind_property ("can-reply", get_action (ACTION_REPLY_ALL), "enabled", BindingFlags.SYNC_CREATE);
        // message_list_box.bind_property ("can-reply", get_action (ACTION_FORWARD), "enabled", BindingFlags.SYNC_CREATE);
        // message_list_box.bind_property ("can-move-thread", get_action (ACTION_MOVE_TO_TRASH), "enabled", BindingFlags.SYNC_CREATE);
        // message_list_box.bind_property ("can-move-thread", get_action (ACTION_ARCHIVE), "enabled", BindingFlags.SYNC_CREATE);
        // message_list_box.bind_property ("can-move-thread", headerbar, "can-mark", BindingFlags.SYNC_CREATE);

        search_entry = new Gtk.SearchEntry () {
            hexpand = true,
            placeholder_text = _("Search Mail"),
            valign = Gtk.Align.CENTER
        };

        var search_header = new Adw.HeaderBar ();
        search_header.add_css_class (Granite.STYLE_CLASS_FLAT);
        search_header.set_title_widget (search_entry);

       //  refresh_button = new Gtk.Button.from_icon_name ("view-refresh-symbolic") {
       //      action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_REFRESH
       //  };

       //  var application_instance = (Gtk.Application) GLib.Application.get_default ();
       //  refresh_button.tooltip_markup = Granite.markup_accel_tooltip (
       //      application_instance.get_accels_for_action (refresh_button.action_name),
       //      _("Fetch new messages")
       //  );

        refresh_spinner = new Gtk.Spinner () {
            spinning = true,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            tooltip_text = _("Fetching new messages…")
        };

        refresh_stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        refresh_stack.add_child (refresh_button);
        refresh_stack.add_child (refresh_spinner);
        refresh_stack.visible_child = refresh_button;

       hide_read_switch = new Granite.SwitchModelButton (_("Hide read conversations"));

        hide_unstarred_switch = new Granite.SwitchModelButton (_("Hide unstarred conversations"));

        var filter_menu_popover_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_bottom = 3,
            margin_top = 3
        };
       filter_menu_popover_box.append (hide_read_switch);
       filter_menu_popover_box.append (hide_unstarred_switch);

        var filter_popover = new Gtk.Popover ();
        filter_popover.set_child (filter_menu_popover_box);

        filter_button = new Gtk.MenuButton () {
            icon_name ="mail-filter-symbolic",
            popover = filter_popover,
            tooltip_text = _("Filter Conversations")
        };

        var conversation_action_bar = new Gtk.ActionBar ();
        conversation_action_bar.pack_start (refresh_stack);
        conversation_action_bar.pack_end (filter_button);
        conversation_action_bar.add_css_class (Granite.STYLE_CLASS_FLAT);

        var conversation_list_grid = new Gtk.Grid ();
        conversation_list_grid.attach (search_header, 0, 0);
        conversation_list_grid.attach (conversation_list_box, 0, 1);
        conversation_list_grid.attach (conversation_action_bar, 0, 2);
        conversation_list_grid.add_css_class (Granite.STYLE_CLASS_VIEW);

       //  message_list_scrolled = new Gtk.ScrolledWindow (null, null);
       //  message_list_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
       //  message_list_scrolled.append (message_list_box);
        // Prevent the focus of the webview causing the ScrolledWindow to scroll
       //  var scrolled_child = message_list_scrolled.get_child ();
       //  if (scrolled_child is Gtk.Box) {
       //      ((Gtk.Box) scrolled_child).set_focus_vadjustment (new Gtk.Adjustment (0, 0, 0, 0, 0, 0));
       //  }

       //  view_overlay = new Gtk.Overlay ();
       //  view_overlay.add_overlay (message_list_scrolled);

       //  var message_list_container = new Gtk.Grid ();
       //  message_list_container.add_css_class (Granite.STYLE_CLASS_BACKGROUND);
       //  message_list_container.attach (headerbar, 0, 0);
       //  message_list_container.attach (view_overlay, 0, 1);

       //  var message_overlay = new Granite.OverlayBar (view_overlay);
       //  message_overlay.no_present = true;

       // message_list_box.hovering_over_link.connect ((label, url) => {
       //      var hover_url = url != null ? GLib.Uri.unescape_string (url) : null;
       //      if (hover_url == null) {
       //          message_overlay.hide ();
       //      } else {
       //          message_overlay.label = hover_url;
       //          message_overlay.show ();
       //      }
       //  });

        paned_start = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned_start.set_start_child (folders_list_view);
        paned_start.set_end_child (conversation_list_grid);

        paned_end = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        paned_end.set_start_child (paned_start);
        // paned_end.set_start_child (message_list_container);

        // var welcome_view = new Mail.WelcomeView ();

        var placeholder_stack = new Gtk.Stack ();
        placeholder_stack.transition_type = Gtk.StackTransitionType.OVER_DOWN_UP;
        placeholder_stack.add_named (paned_end, "mail");
        //placeholder_stack.add_named (welcome_view, "welcome");

        set_content (placeholder_stack);

        //@TODO: lookup a new implementation for Hdy.HeaderGroup
        // var header_group = new Adw.HeaderGroup ();
        // header_group.append_header_bar (folders_list_view.header_bar);
        // header_group.append_header_bar (search_header);
        // header_group.append_header_bar (headerbar);

        var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.VERTICAL);
        size_group.add_widget (folders_list_view.header_bar);
        size_group.add_widget (search_header);
        //size_group.add_widget (headerbar);

        var settings = new GLib.Settings ("io.elementary.mail");
        settings.bind ("paned-start-position", paned_start, "position", SettingsBindFlags.DEFAULT);
        settings.bind ("paned-end-position", paned_end, "position", SettingsBindFlags.DEFAULT);

        //close_request.connect (() => destroy ()); //@TODO: check whether that is wanted? previously: destroy().connect

        folders_list_view.folder_selected.connect ((folder_full_name_per_account) => {
           conversation_list_box.load_folder.begin (folder_full_name_per_account);
        });

       // conversation_list_box.conversation_selected.connect ((node) => {
       //     message_list_box.set_conversation (node);

       //     if (node != null && node.message != null && Camel.MessageFlags.DRAFT in (int) node.message.flags) {
       //         message_list_box.append_inline_composer.begin (ComposerWidget.Type.DRAFT, null, (obj, res) => {
       //            message_list_box.append_inline_composer.end (res);
       //              scroll_message_list_to_bottom ();
       //          });
       //     }
       // });

       //  search_entry.bind_property ("sensitive", filter_button, "sensitive", BindingFlags.SYNC_CREATE);

       // hide_read_switch.notify["active"].connect (on_filter_button_changed);
       // hide_unstarred_switch.notify["active"].connect (on_filter_button_changed);

       //  search_entry.search_changed.connect (() => {
       //      if (search_changed_debounce_timeout_id != 0) {
       //          GLib.Source.remove (search_changed_debounce_timeout_id);
       //      }

       //      search_changed_debounce_timeout_id = GLib.Timeout.add (800, () => {
       //          search_changed_debounce_timeout_id = 0;

       //          var search_term = search_entry.text.strip ();
       //         conversation_list_box.search.begin (search_term == "" ? null : search_term);

       //          return GLib.Source.REMOVE;
       //      });
       //  });

        unowned Mail.Backend.Session session = Mail.Backend.Session.get_default ();

        session.account_removed.connect (() => {
            var accounts_left = session.get_accounts ();
            if (accounts_left.size == 0) {
                //get_action (ACTION_COMPOSE_MESSAGE).set_enabled (false);
                search_entry.sensitive = false;
            }
        });

        session.start.begin ((obj, res) => {
            session.start.end (res);

            if (session.get_accounts ().size > 0) {
                placeholder_stack.visible_child = paned_end;
                //get_action (ACTION_COMPOSE_MESSAGE).set_enabled (true);
                search_entry.sensitive = true;
            }

            is_session_started = true;
            session_started ();
        });
     }

    private void on_filter_button_changed () {
        // var style_context = filter_button.get_style_context ();
        // if (hide_read_switch.active || hide_unstarred_switch.active) {
        //     if (!filter_button.has_css_class (Granite.STYLE_CLASS_ACCENT)) {
        //         filter_button.add_css_class (Granite.STYLE_CLASS_ACCENT);
        //     }
        // } else if (filter_button.has_css_class (Granite.STYLE_CLASS_ACCENT)) {
        //     filter_button.remove_css_class (Granite.STYLE_CLASS_ACCENT);
        // }

        // conversation_list_box.search.begin (search_entry.text, hide_read_switch.active, hide_unstarred_switch.active);
    }

    private void on_compose_message () {
        // new ComposerWindow (this).present ();
    }

    private void on_refresh () {
        // refresh_stack.visible_child = refresh_spinner;

        // conversation_list_box.refresh_folder.begin (null, (obj, res) => {
        //     conversation_list_box.refresh_folder.end (res);

        //     refresh_stack.visible_child = refresh_button;
        // });
    }

    private void scroll_message_list_to_bottom () {
        // appending the inline composer then trying to scroll to the bottom doesn't work as
        // the scrolled window doesn't resize instantly. So connect a one time signal to
        // scroll to the bottom when the inline composer is appended
        // var adjustment = message_list_scrolled.get_vadjustment ();
        // ulong changed_id = 0;
        // changed_id = adjustment.changed.connect (() => {
        //     adjustment.set_value (adjustment.get_upper ());
        //     adjustment.disconnect (changed_id);
        // });
    }

    private void on_mark_read () {
       //conversation_list_box.mark_read_selected_messages ();
    }

    private void on_mark_star () {
       //conversation_list_box.mark_star_selected_messages ();
    }

    private void on_mark_unread () {
       //conversation_list_box.mark_unread_selected_messages ();
    }

    private void on_mark_unstar () {
       //conversation_list_box.mark_unstar_selected_messages ();
    }

    private void on_reply () {
       // scroll_message_list_to_bottom ();
       //message_list_box.append_inline_composer.begin (ComposerWidget.Type.REPLY);
    }

    private void on_reply_all () {
       // scroll_message_list_to_bottom ();
       //message_list_box.append_inline_composer.begin (ComposerWidget.Type.REPLY_ALL);
    }

    private void on_forward () {
       // scroll_message_list_to_bottom ();
       //message_list_box.append_inline_composer.begin (ComposerWidget.Type.FORWARD);
    }

    private void on_archive () {
       //conversation_list_box.archive_selected_messages.begin ((obj, res) => {
       //    conversation_list_box.archive_selected_messages.end (res);
       //});
    }

    private void on_move_to_trash () {
       // var result = conversation_list_box.trash_selected_messages ();
       //  if (result > 0) {
       //      send_move_toast (ngettext ("Message Deleted", "Messages Deleted", result));
       //  }
    }

    private void send_move_toast (string message) {
        // var overlay_child = view_overlay.get_child();
        // if (overlay_child.get_type() ==  typeof(Granite.Toast)) {
        //         overlay_child.destroy ();
        // }

        // var toast = new Granite.Toast (message);
        // toast.set_default_action (_("Undo"));

        // toast.default_action.connect (() => {
        //     conversation_list_box.undo_move ();
        // });

        // toast.closed.connect (() => {
        //     conversation_list_box.undo_expired ();
        // });

        // view_overlay.set_child (toast);
        // toast.send_notification ();
    }

    private void on_fullscreen () {
        // if (is_fullscreen()) {
        //     headerbar.show_title_buttons = true;
        //     unfullscreen ();
        // } else {
        //     headerbar.show_title_buttons = false;
        //     fullscreen ();
        // }
    }

    // private SimpleAction? get_action (string name) {
    //     return lookup_action (name) as SimpleAction;
    // }

    // public override bool configure_event (Gdk.Event event) {
        // if (configure_id != 0) {
        //     GLib.Source.remove (configure_id);
        // }

        // configure_id = Timeout.add (100, () => {
        //     configure_id = 0;

        //     if (is_maximized()) {
        //         Mail.Application.settings.set_boolean ("window-maximized", true);
        //     } else {
        //         Mail.Application.settings.set_boolean ("window-maximized", false);

        //         Gdk.Rectangle rect;
        //         get_allocation (out rect);
        //         Mail.Application.settings.set ("window-size", "(ii)", rect.width, rect.height);

        //         int root_x, root_y;
        //         get_position (out root_x, out root_y);
        //         Mail.Application.settings.set ("window-position", "(ii)", root_x, root_y);
        //     }

        //     return false;
        // });

        // return base.configure_event (event);
    // }
}
