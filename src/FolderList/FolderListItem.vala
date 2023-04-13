public class FolderListItem : Gtk.Box {
    private Gtk.Image image;
    private Gtk.Label label;

    construct {
        orientation = HORIZONTAL;

        label = new Gtk.Label ("");

        append (label);
    }

    public void bind_account (AccountItemModel item_model) {
        label.label = item_model.name;
    }

    public void bind_folder (FolderItemModel item_model) {
        label.label = item_model.name;
    }

}
