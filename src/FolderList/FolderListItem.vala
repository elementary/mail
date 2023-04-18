public class FolderListItem : Gtk.Box {
    private Gtk.Image image;
    private Gtk.Label label;

    private Mail.FolderItemModel? folder_item = null;

    private const string ACTION_GROUP_PREFIX = "folderlistitem";
    private const string ACTION_PREFIX = ACTION_GROUP_PREFIX + ".";
    private const string ACTION_REFRESH = "refresh";

    construct {
        var refresh_action = new SimpleAction (ACTION_REFRESH, null);
        refresh_action.activate.connect (on_refresh);

        var actions = new SimpleActionGroup ();
        actions.add_action (refresh_action);
        insert_action_group (ACTION_GROUP_PREFIX, actions);

        var gesture_secondary_click = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        add_controller (gesture_secondary_click);

        var context_menu_model = new Menu ();
        context_menu_model.append (_("Refresh"), ACTION_PREFIX + ACTION_REFRESH);

        var menu = new Gtk.PopoverMenu.from_model (context_menu_model) {
            has_arrow = false
        };
        menu.set_parent (this);

        image = new Gtk.Image ();
        label = new Gtk.Label ("") {
            margin_start = 3
        };

        hexpand = true;
        vexpand = true;
        orientation = HORIZONTAL;

        append (image);
        append (label);

        gesture_secondary_click.pressed.connect ((n_press, x, y) => {
            if (folder_item != null) {
                var rect = Gdk.Rectangle () {
                    x = (int) x,
                    y = (int) y
                };
                menu.pointing_to = rect;
                menu.popup ();
            }
        });
    }

    public void bind_account (Mail.AccountItemModel item_model) {
        folder_item = null;

        image.set_from_icon_name ("");
        label.label = item_model.name;
    }

    public void bind_folder (Mail.FolderItemModel item_model) {
        folder_item = item_model;

        image.set_from_icon_name (item_model.icon_name);
        label.label = item_model.name;
    }

    private void on_refresh () {
        if (folder_item != null) {
            folder_item.refresh.begin ();
        }
    }
}
