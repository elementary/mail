/* Copyright 2013-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class ComposerEmbed : Gtk.ListBoxRow, ComposerContainer {
    
    private const int MIN_EDITOR_HEIGHT = 200;
    
    private ComposerWidget composer;
    private ConversationViewer conversation_viewer;
    private string embed_id;
    private bool setting_inner_scroll;
    private bool scrolled_to_bottom = false;
    private double inner_scroll_adj_value;
    private int inner_view_height;
    private int min_height = MIN_EDITOR_HEIGHT;
    private bool has_accel_group = false;
    
    public Gtk.Window top_window {
        get { return (Gtk.Window) get_toplevel(); }
    }
    
    public ComposerEmbed(ComposerWidget composer, ConversationViewer conversation_viewer, Geary.Email referred) {
        this.composer = composer;
        this.conversation_viewer = conversation_viewer;
        get_style_context().add_class("card");
        margin = 12;
        margin_bottom = 3;
        var grid = new Gtk.Grid();
        grid.expand = true;
        grid.margin = 6;
        grid.add(composer);
        add(grid);
        composer.editor.focus_in_event.connect(on_focus_in);
        composer.editor.focus_out_event.connect(on_focus_out);
        conversation_viewer.conversation_list_box.add (this);
        show_all();
        present();
    }
    
    private void reroute_scroll_handling(Gtk.Widget widget) {
        widget.add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.SMOOTH_SCROLL_MASK);
        widget.scroll_event.connect(on_inner_scroll_event);
        Gtk.Container? container = widget as Gtk.Container;
        if (container != null) {
            foreach (Gtk.Widget child in container.get_children())
                reroute_scroll_handling(child);
        }
    }
    
    private void disable_scroll_reroute(Gtk.Widget widget) {
        widget.scroll_event.disconnect(on_inner_scroll_event);
        Gtk.Container? container = widget as Gtk.Container;
        if (container != null) {
            foreach (Gtk.Widget child in container.get_children())
                disable_scroll_reroute(child);
        }
    }
    
    public void remove_composer() {
        if (composer.editor.has_focus)
            on_focus_out();
        composer.editor.focus_in_event.disconnect(on_focus_in);
        composer.editor.focus_out_event.disconnect(on_focus_out);
        composer.editor.vadjustment.value_changed.disconnect(on_inner_scroll);
        composer.editor.user_changed_contents.disconnect(on_inner_size_changed);
        disable_scroll_reroute(this);
        Gtk.ScrolledWindow win = (Gtk.ScrolledWindow) composer.editor.parent;
        win.get_vscrollbar().show();
        
        composer.parent.remove(composer);
        close_container();
    }
    
    public bool set_position(ref Gdk.Rectangle allocation, double hscroll, double vscroll,
        int view_height) {
        WebKit.DOM.Element embed = conversation_viewer.web_view.get_dom_document().get_element_by_id(embed_id);
        if (embed == null)
            return false;
        
        int div_height = (int) embed.client_height;
        int y_top = (int) (embed.offset_top + embed.client_top) - (int) vscroll;
        int available_height = int.min(y_top + div_height, view_height) - int.max(y_top, 0);
        
        if (available_height < 0 || available_height == div_height) {
            // It fits in the available space, or it doesn't fit at all
            allocation.y = y_top;
            // When offscreen, make it very small to ensure scrolling during any edit
            allocation.height = (available_height < 0) ? 1 : div_height;
        } else if (available_height > min_height) {
            // There's enough room, so make sure we get the whole widget in
            allocation.y = int.max(y_top, 0);
            allocation.height = available_height;
        } else {
            // Minimum height widget, placed so as much as possible is visible
            allocation.y = int.max(y_top, int.min(y_top + div_height - min_height, 0));
            allocation.height = min_height;
        }
        allocation.x = (int) (embed.offset_left + embed.client_left) - (int) hscroll;
        allocation.width = (int) embed.client_width;
        
        // Work out adjustment of composer web view
        setting_inner_scroll = true;
        composer.editor.vadjustment.set_value(allocation.y - y_top);
        setting_inner_scroll = false;
        // This sets the scroll before the widget gets resized.  Although the adjustment
        // may be scrolled to the bottom right now, the current value may not do that
        // once the widget is shrunk; for example, while scrolling down the page past
        // the bottom of the editor.  So if we're at the bottom, record that fact.  When
        // the limits of the adjustment are changed (watched by on_adjust_changed), we
        // can keep it at the bottom.
        scrolled_to_bottom = (y_top <= 0 && available_height < view_height);
        
        return true;
    }
    
    private bool on_focus_in() {
        // For some reason, on_focus_in gets called a bunch upon construction.
        if (!has_accel_group)
            top_window.add_accel_group(composer.ui.get_accel_group());
        has_accel_group = true;
        return false;
    }
    
    private bool on_focus_out() {
        top_window.remove_accel_group(composer.ui.get_accel_group());
        has_accel_group = false;
        return false;
    }
    
    private void on_inner_scroll(Gtk.Adjustment adj) {
        double delta = adj.value - inner_scroll_adj_value;
        inner_scroll_adj_value = adj.value;
        if (delta != 0 && !setting_inner_scroll) {
            Gtk.Adjustment outer_adj = conversation_viewer.web_view.vadjustment;
            outer_adj.set_value(outer_adj.value + delta);
        }
    }
    
    private void on_inner_size_changed() {
        scrolled_to_bottom = false;  // The inserted character may cause a desired scroll
        Idle.add(recalc_height);  // So that this runs after the character has been inserted
    }
    
    private bool recalc_height() {
        int view_height,
            base_height = get_allocated_height() - composer.editor.get_allocated_height();
        try {
            view_height = (int) composer.editor.get_dom_document()
                .query_selector("#message-body").offset_height;
        } catch (Error error) {
            debug("Error getting height of editor: %s", error.message);
            return false;
        }
        
        if (view_height != inner_view_height || min_height != base_height + MIN_EDITOR_HEIGHT) {
            inner_view_height = view_height;
            min_height = base_height + MIN_EDITOR_HEIGHT;
            // Calculate height widget should be to avoid scrolling in editor
            int widget_height = int.max(view_height + base_height - 2, min_height); //? about 2
            WebKit.DOM.Element embed = conversation_viewer.web_view
                .get_dom_document().get_element_by_id(embed_id);
            if (embed != null) {
                try {
                    embed.style.set_property("height", @"$widget_height", "");
                } catch (Error error) {
                    debug("Error setting height of composer widget");
                }
            }
        }
        return false;
    }
    
    private bool on_inner_scroll_event(Gdk.EventScroll event) {
        conversation_viewer.web_view.scroll_event(event);
        return true;
    }
    
    public void present() {
        top_window.present();
        conversation_viewer.web_view.get_dom_document().get_element_by_id(embed_id)
            .scroll_into_view_if_needed(false);
    }
    
    public unowned Gtk.Widget get_focus() {
        return top_window.get_focus();
    }
    
    public void vanish() {
        hide();
        composer.state = ComposerWidget.ComposerState.DETACHED;
        composer.editor.focus_in_event.disconnect(on_focus_in);
        composer.editor.focus_out_event.disconnect(on_focus_out);
    }
    
    public void close_container() {
        if (visible)
            vanish();
        destroy();
    }
}

