public class FolderListItem : Gtk.Box {
    private Gtk.Image image;
    private Gtk.Label label;

    construct {
        orientation = HORIZONTAL;

        image = new Gtk.Image ();
        label = new Gtk.Label ("");

        append (image);
        append (label);
    }

    public void bind_account (Mail.AccountItemModel item_model) {
        image.set_from_icon_name ("");
        label.label = item_model.name;
    }

    public void bind_folder (Mail.FolderItemModel item_model) {
        image.set_from_icon_name (item_model.icon_name);
        label.label = item_model.name;
    }

}
