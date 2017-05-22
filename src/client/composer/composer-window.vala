/* Copyright 2011-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class ComposerWindow : Gtk.ApplicationWindow, ComposerContainer {

    public Gtk.ApplicationWindow top_window {
        get { return this; }
    }

    internal ComposerWidget composer { get; set; }

    protected Gee.MultiMap<string, string>? old_accelerators { get; set; }

    private bool closing = false;


    public ComposerWindow(ComposerWidget composer) {
        Object(type: Gtk.WindowType.TOPLEVEL);
        this.composer = composer;

        // Make sure it gets added to the GtkApplication, to get the window-specific
        // composer actions to work properly.
        GearyApplication.instance.add_window(this);

        add(composer);
        focus_in_event.connect(on_focus_in);
        focus_out_event.connect(on_focus_out);

        composer.header.show_close_button = true;
        composer.free_header();
        set_titlebar(composer.header);
        composer.bind_property("window-title", composer.header, "title",
                               BindingFlags.SYNC_CREATE);

        show();
        set_position(Gtk.WindowPosition.CENTER);
    }

    public override void show() {
        set_default_size(680, 600);
        base.show();
    }

    public void close_container() {
        on_focus_out();
        this.composer.editor.focus_in_event.disconnect(on_focus_in);
        this.composer.editor.focus_out_event.disconnect(on_focus_out);

        this.closing = true;
        destroy();
    }

    public override bool delete_event(Gdk.EventAny event) {
        return !(closing ||
            ((ComposerWidget) get_child()).should_close() == ComposerWidget.CloseStatus.DO_CLOSE);
    }

    public void vanish() {
        hide();
    }

    public void remove_composer() {
        warning("Detached composer received remove");
    }
}


