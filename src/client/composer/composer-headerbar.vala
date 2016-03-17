/* Copyright 2014-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class ComposerHeaderbar : PillHeaderbar {

    public ComposerWidget.ComposerState state { get; set; }
    public bool show_pending_attachments { get; set; default = false; }
    public bool send_enabled { get; set; default = false; }

    private Gtk.Button recipients;
    private Gtk.Label recipients_label;
    private Gtk.Button detach_start;
    private Gtk.Button detach_end;

    public ComposerHeaderbar(Gtk.ActionGroup action_group) {
        base(action_group);

        Gee.List<Gtk.Button> insert = new Gee.ArrayList<Gtk.Button>();

        detach_start = new Gtk.Button.from_icon_name ("window-pop-out-symbolic", Gtk.IconSize.MENU);
        detach_start.related_action = action_group.get_action (ComposerWidget.ACTION_DETACH);
        detach_start.margin_end = 6;
        detach_start.tooltip_text = _("Detach (Ctrl+D)");

        detach_end = new Gtk.Button.from_icon_name ("window-pop-out-symbolic", Gtk.IconSize.MENU);
        detach_end.related_action = action_group.get_action (ComposerWidget.ACTION_DETACH);
        detach_end.margin_start = 6;
        detach_end.tooltip_text = detach_end.related_action.tooltip;

        Gtk.Button discard = new Gtk.Button.from_icon_name ("edit-delete-symolic", Gtk.IconSize.MENU);
        discard.related_action = action_group.get_action (ComposerWidget.ACTION_CLOSE_DISCARD);
        discard.tooltip_text = _("Close and Discard");

        Gtk.Button send_button = new Gtk.Button.from_icon_name ("mail-send-symbolic", Gtk.IconSize.MENU);
        send_button.related_action = action_group.get_action (ComposerWidget.ACTION_SEND);
        send_button.always_show_image = true;
        send_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        send_button.label = _("Send");
        send_button.tooltip_text = _("Send (Ctrl+Enter)");


        Gtk.Box attach_buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        Gtk.Button attach_only = create_toolbar_button(null, ComposerWidget.ACTION_ADD_ATTACHMENT);
        insert.add(create_toolbar_button(null, ComposerWidget.ACTION_ADD_ATTACHMENT));
        insert.add(create_toolbar_button(null, ComposerWidget.ACTION_ADD_ORIGINAL_ATTACHMENTS));
        Gtk.Box attach_pending = create_pill_buttons(insert, false);
        attach_buttons.pack_start(attach_only);
        attach_buttons.pack_start(attach_pending);

        recipients = new Gtk.Button();
        recipients.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        recipients_label = new Gtk.Label(null);
        recipients_label.set_ellipsize(Pango.EllipsizeMode.END);
        recipients.add(recipients_label);
        recipients.clicked.connect(() => { state = ComposerWidget.ComposerState.INLINE; });

        bind_property("state", recipients, "visible", BindingFlags.SYNC_CREATE,
            (binding, source_value, ref target_value) => {
                target_value = (state == ComposerWidget.ComposerState.INLINE_COMPACT);
                return true;
            });
        bind_property("show-pending-attachments", attach_only, "visible", BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);
        bind_property("show-pending-attachments", attach_pending, "visible", BindingFlags.SYNC_CREATE);
        bind_property("send-enabled", send_button, "sensitive", BindingFlags.SYNC_CREATE);

        pack_start (detach_start);
        pack_start (attach_buttons);
        pack_start (recipients);

        pack_end (detach_end);
        pack_end (send_button);
        pack_end (discard);

        notify["decoration-layout"].connect(set_detach_button_side);

        realize.connect(set_detach_button_side);
        notify["state"].connect((s, p) => {
            if (state == ComposerWidget.ComposerState.DETACHED) {
                notify["decoration-layout"].disconnect(set_detach_button_side);
                detach_start.visible = detach_end.visible = false;
            }
        });
    }

    public void set_recipients(string label, string tooltip) {
        recipients_label.label = label;
        recipients.tooltip_text = tooltip;
    }

    private void set_detach_button_side() {
        bool at_end = close_button_at_end();
        detach_start.visible = !at_end;
        detach_end.visible = at_end;
    }
}

