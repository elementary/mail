/* Copyright 2011-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * A WebKit view displaying all the emails in a {@link Geary.App.Conversation}.
 *
 * Unlike ConversationListStore (which sorts by date received), ConversationViewer sorts by the
 * {@link Geary.Email.date} field (the Date: header), as that's the date displayed to the user.
 */

public class ConversationViewer : Gtk.Stack {
    public const Geary.Email.Field REQUIRED_FIELDS =
        Geary.Email.Field.HEADER
        | Geary.Email.Field.BODY
        | Geary.Email.Field.ORIGINATORS
        | Geary.Email.Field.RECEIVERS
        | Geary.Email.Field.SUBJECT
        | Geary.Email.Field.DATE
        | Geary.Email.Field.FLAGS
        | Geary.Email.Field.PREVIEW;
    
    private const int ATTACHMENT_PREVIEW_SIZE = 50;
    private const int SELECT_CONVERSATION_TIMEOUT_MSEC = 100;
    private const string MESSAGE_CONTAINER_ID = "message_container";
    private const string SELECTION_COUNTER_ID = "multiple_messages";
    private const string SPINNER_ID = "spinner";
    private const string REPLACED_IMAGE_CLASS = "replaced_inline_image";
    private const string DATA_IMAGE_CLASS = "data_inline_image";
    private const int MAX_INLINE_IMAGE_MAJOR_DIM = 1024;
    private const int QUOTE_SIZE_THRESHOLD = 120;
    // The upper and lower margin on which the mail is considered as not viewed.
    private static const int READ_MARGIN = 100;
    
    private static const string EMBEDDED_CSS = """
        .deck {
            background-color: shade (shade (#FFF, 0.96), 0.92);
        }

        .card {
            background-color: #fff;
            border: none;
            box-shadow: 0 0 0 1px alpha (#000, 0.05),
                        0 3px 3px alpha (#000, 0.22);
            transition: all 150ms ease-in-out;
        }

        .card.collapsed {
            background-color: #f5f5f5;
            box-shadow: 0 0 0 1px alpha (#000, 0.05),
                        0 1px 2px alpha (#000, 0.22);
        }
    """;
    
    private enum SearchState {
        // Search/find states.
        NONE,         // Not in search
        FIND,         // Find toolbar
        SEARCH_FOLDER, // Search folder
        
        COUNT;
    }
    
    private enum SearchEvent {
        // User-initated events.
        RESET,
        OPEN_FIND_BAR,
        CLOSE_FIND_BAR,
        ENTER_SEARCH_FOLDER,
        
        COUNT;
    }
    
    // Main display mode.
    private enum DisplayMode {
        NONE = 0,     // Nothing is shown (ni
        CONVERSATION, // Email conversation
        MULTISELECT,  // Message indicating that <> 1 conversations are selected
        LOADING,      // Loading spinner
        
        COUNT;
    }
    
    // Fired when the user clicks a link.
    public signal void link_selected(string link);
    
    // Fired when the user clicks "reply" in the message menu.
    public signal void reply_to_message(Geary.Email message);

    // Fired when the user clicks "reply all" in the message menu.
    public signal void reply_all_message(Geary.Email message);

    // Fired when the user clicks "forward" in the message menu.
    public signal void forward_message(Geary.Email message);

    // Fired when the user mark messages.
    public signal void mark_messages(Gee.Collection<Geary.EmailIdentifier> emails,
        Geary.EmailFlags? flags_to_add, Geary.EmailFlags? flags_to_remove);

    // Fired when the user opens an attachment.
    public signal void open_attachment(Geary.Attachment attachment);

    // Fired when the user wants to save one or more attachments.
    public signal void save_attachments(Gee.List<Geary.Attachment> attachment);
    
    // Fired when the user wants to save an image buffer to disk
    public signal void save_buffer_to_file(string? filename, Geary.Memory.Buffer buffer);
    
    // Fired when the user clicks the edit draft button.
    public signal void edit_draft(Geary.Email message);
    
    // Fired when the viewer has been cleared.
    public signal void cleared();
    
    // List of emails in this view.
    public Gee.TreeSet<Geary.Email> messages { get; private set; default = 
        new Gee.TreeSet<Geary.Email>(Geary.Email.compare_sent_date_ascending); }
    
    // The HTML viewer to view the emails.
    public Gtk.ListBox conversation_list_box { get; private set; }
    private Gtk.ScrolledWindow conversation_scrolled;
    
    private Gtk.Label message_label;
    private Gtk.Grid conversation_grid;
    
    // Current conversation, or null if none.
    public Geary.App.Conversation? current_conversation = null;
    
    // Overlay consisting of a label in front of a webpage
    private Granite.Widgets.OverlayBar message_overlay;
    
    // State machine setup for search/find modes.
    private Geary.State.MachineDescriptor search_machine_desc = new Geary.State.MachineDescriptor(
        "ConversationViewer search", SearchState.NONE, SearchState.COUNT, SearchEvent.COUNT, null, null);
    
    private string? hover_url = null;
    private weak Geary.Folder? current_folder = null;
    private weak Geary.SearchFolder? search_folder = null;
    private Geary.App.EmailStore? email_store = null;
    private Geary.AccountInformation? current_account_information = null;
    private ConversationFindBar conversation_find_bar;
    private Cancellable cancellable_fetch = new Cancellable();
    private Geary.State.Machine fsm;
    private DisplayMode display_mode = DisplayMode.NONE;
    private uint select_conversation_timeout_id = 0;
    private bool stay_down = true;   
    
    public ConversationViewer() {
        transition_type = Gtk.StackTransitionType.CROSSFADE;
        // Setup state machine for search/find states.
        Geary.State.Mapping[] mappings = {
            new Geary.State.Mapping(SearchState.NONE, SearchEvent.RESET, on_reset),
            new Geary.State.Mapping(SearchState.NONE, SearchEvent.OPEN_FIND_BAR, on_open_find_bar),
            new Geary.State.Mapping(SearchState.NONE, SearchEvent.CLOSE_FIND_BAR, on_close_find_bar),
            new Geary.State.Mapping(SearchState.NONE, SearchEvent.ENTER_SEARCH_FOLDER, on_enter_search_folder),
            
            new Geary.State.Mapping(SearchState.FIND, SearchEvent.RESET, on_reset),
            new Geary.State.Mapping(SearchState.FIND, SearchEvent.OPEN_FIND_BAR, Geary.State.nop),
            new Geary.State.Mapping(SearchState.FIND, SearchEvent.CLOSE_FIND_BAR, on_close_find_bar),
            new Geary.State.Mapping(SearchState.FIND, SearchEvent.ENTER_SEARCH_FOLDER, Geary.State.nop),
            
            new Geary.State.Mapping(SearchState.SEARCH_FOLDER, SearchEvent.RESET, on_reset),
            new Geary.State.Mapping(SearchState.SEARCH_FOLDER, SearchEvent.OPEN_FIND_BAR, on_open_find_bar),
            new Geary.State.Mapping(SearchState.SEARCH_FOLDER, SearchEvent.CLOSE_FIND_BAR, on_close_find_bar),
            new Geary.State.Mapping(SearchState.SEARCH_FOLDER, SearchEvent.ENTER_SEARCH_FOLDER, Geary.State.nop),
        };
        
        fsm = new Geary.State.Machine(search_machine_desc, mappings, null);
        fsm.set_logging(false);
        
        GearyApplication.instance.controller.conversations_selected.connect(on_conversations_selected);
        GearyApplication.instance.controller.folder_selected.connect(on_folder_selected);
        GearyApplication.instance.controller.conversation_count_changed.connect(on_conversation_count_changed);
        
        conversation_list_box = new Gtk.ListBox();
        conversation_list_box.expand = true;
        conversation_list_box.get_style_context().add_class("deck");
        conversation_list_box.set_selection_mode(Gtk.SelectionMode.NONE);
        conversation_list_box.set_sort_func(sort_messages);
        conversation_list_box.set_header_func(header_margin_hack);
        conversation_scrolled = new Gtk.ScrolledWindow(null, null);
        conversation_scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;
        conversation_scrolled.add(conversation_list_box);
        conversation_scrolled.size_allocate.connect(mark_read);
        conversation_scrolled.vadjustment.value_changed.connect(mark_read);
        conversation_scrolled.vadjustment.changed.connect (() => {
            if (stay_down) {
                var last_child = conversation_list_box.get_row_at_index ((int)conversation_list_box.get_children ().length () -1);
                conversation_scrolled.vadjustment.value = conversation_scrolled.vadjustment.upper - last_child.get_allocated_height () - 18;
            }
        });
        
        // Stops button_press_event
        conversation_list_box.button_press_event.connect ((b) => {            
            return true;
        });               
        
        try {
            var css_provider = new Gtk.CssProvider();
            css_provider.load_from_data(EMBEDDED_CSS, EMBEDDED_CSS.length);
            Gtk.StyleContext.add_provider_for_screen(conversation_list_box.get_screen(), css_provider, Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK);
        } catch (Error e) {
            critical(e.message);
        }
        
        var view_overlay = new Gtk.Overlay();
        view_overlay.add(conversation_scrolled);
        
        message_overlay = new Granite.Widgets.OverlayBar(view_overlay);
        
        conversation_find_bar = new ConversationFindBar(conversation_list_box);
        conversation_find_bar.notify["child-revealed"].connect(() => {
            if (conversation_find_bar.child_revealed) {
                fsm.issue(SearchEvent.OPEN_FIND_BAR);
            } else {
                fsm.issue(SearchEvent.CLOSE_FIND_BAR);
            }
        });
        
        conversation_grid = new Gtk.Grid();
        conversation_grid.orientation = Gtk.Orientation.VERTICAL;
        conversation_grid.expand = true;
        conversation_grid.add(conversation_find_bar);
        conversation_grid.add(view_overlay);
        
        message_label = new Gtk.Label(null);
        message_label.get_style_context().add_class("h2");
        message_label.expand = true;
        message_label.halign = Gtk.Align.CENTER;
        message_label.valign = Gtk.Align.CENTER;
        
        add(conversation_grid);
        add(message_label);
    }
    
    public void set_paned_composer(ComposerWidget composer) {
        if (composer.state == ComposerWidget.ComposerState.NEW) {
            clear(current_folder, current_account_information);
        }

        var container = new ComposerCard(composer);
        container.show_all();
        conversation_list_box.add(container);
        conversation_scrolled.vadjustment.value = conversation_scrolled.vadjustment.upper - container.get_allocated_height () - 18;
    }
    
    public Geary.Email? get_last_message() {
        return messages.is_empty ? null : messages.last();
    }
    
    public Geary.Email? get_selected_message(out string? quote) {
        quote = null;
        return get_last_message();
    }
    
    // Removes all displayed e-mails from the view.
    private void clear(Geary.Folder? new_folder, Geary.AccountInformation? account_information) {
        conversation_list_box.get_children().foreach((child) => {
            child.destroy();
        });
        
        messages.clear();
        current_account_information = account_information;
        cleared();
    }
    
    // Converts an email ID into HTML ID used by the <div> for the email.
    public string get_div_id(Geary.EmailIdentifier id) {
        return "message_%s".printf(id.to_string());
    }

    [CCode (instance_pos = -1)]
    private void header_margin_hack (Gtk.ListBoxRow row, Gtk.ListBoxRow? before)  {
        if (before == null) {
            row.margin_top = 12;
        } else {
            row.margin_top = 0;
        }
    }
    
    [CCode (instance_pos = -1)]
    private int sort_messages(Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        if (!(row1 is ConversationWidget && row2 is ConversationWidget)) {
            return 0;
        }

        return Geary.Email.compare_sent_date_ascending(((ConversationWidget) row1).email, ((ConversationWidget) row2).email);
    }
    
    private void show_special_message(string msg) {
        message_label.label = msg;
        set_visible_child(message_label);
    }
    
    private void hide_special_message() {
        set_visible_child(conversation_grid);
        if (display_mode != DisplayMode.MULTISELECT)
            return;
        
        clear(current_folder, current_account_information);
        set_mode(DisplayMode.NONE);
    }
    
    private void show_multiple_selected(uint selected_count) {
        if (selected_count == 0) {
            show_special_message(_("No conversations selected."));
        } else {
            show_special_message(ngettext("%u conversation selected.", "%u conversations selected.",
                selected_count).printf(selected_count));
        }
    }
    
    private void on_folder_selected(Geary.Folder? folder) {
        hide_special_message();
        
        current_folder = folder;
        email_store = (current_folder == null ? null : new Geary.App.EmailStore(current_folder.account));
        fsm.issue(SearchEvent.RESET);
        
        if (folder == null) {
            clear(null, null);
            current_conversation = null;
        }
        
        if (current_folder is Geary.SearchFolder) {
            fsm.issue(SearchEvent.ENTER_SEARCH_FOLDER);
            allow_collapsing(false);
        } else {
            allow_collapsing(true);
        }
    }
    
    private void on_conversation_count_changed(int count) {
        if (count != 0)
            hide_special_message();
        else if (current_folder is Geary.SearchFolder)
            show_special_message(_("No search results found."));
        else
            show_special_message(_("No conversations in folder."));
    }
    
    private void on_conversations_selected(Gee.Set<Geary.App.Conversation>? conversations,
        Geary.Folder? current_folder) {
        cancel_load();
        // Clear the URL overlay
        on_hovering_over_link(null, null);
        if (current_conversation != null) {
            current_conversation.appended.disconnect(on_conversation_appended);
            current_conversation.trimmed.disconnect(on_conversation_trimmed);
            current_conversation.email_flags_changed.disconnect(update_flags);
            current_conversation = null;
        }
        
        // Disable message buttons until conversation loads.
        GearyApplication.instance.controller.enable_message_buttons(false);
        
        if (conversations == null || conversations.size == 0 || current_folder == null) {
            show_multiple_selected(0);
            return;
        }
        
        if (conversations.size == 1) {
            set_visible_child(conversation_grid);
            clear(current_folder, current_folder.account.information);
            
            if (select_conversation_timeout_id != 0)
                Source.remove(select_conversation_timeout_id);
            
            // If the load is taking too long, display a spinner.
            select_conversation_timeout_id = Timeout.add(SELECT_CONVERSATION_TIMEOUT_MSEC, () => {
                if (select_conversation_timeout_id != 0)
                    set_mode(DisplayMode.LOADING);
                
                return false;
            });
            
            current_conversation = Geary.Collection.get_first(conversations);
            
            // Disable marking emails as read until the view is filled
            conversation_scrolled.vadjustment.value_changed.disconnect(mark_read);
            select_conversation_async.begin(current_conversation, current_folder, (obj, res) => {
                try {
                    select_conversation_async.end(res);
                    // Re-enable marking emails as read
                    conversation_scrolled.vadjustment.value_changed.connect(mark_read);
                    mark_read();
                } catch (Error err) {
                    debug("Unable to select conversation: %s", err.message);
                }
            });
            
            current_conversation.appended.connect(on_conversation_appended);
            current_conversation.trimmed.connect(on_conversation_trimmed);
            current_conversation.email_flags_changed.connect(update_flags);
            
            GearyApplication.instance.controller.enable_message_buttons(true);
        } else if (conversations.size > 1) {
            show_multiple_selected(conversations.size);
            
            GearyApplication.instance.controller.enable_multiple_message_buttons();
        }
    }
    
    private async void select_conversation_async(Geary.App.Conversation conversation,
        Geary.Folder current_folder) throws Error {
        // Load this once, so if it's cancelled, we cancel the WHOLE load.
        Cancellable cancellable = cancellable_fetch;
        
        // Fetch full messages.
        Gee.Collection<Geary.Email>? messages_to_add
            = yield list_full_messages_async(conversation.get_emails(
            Geary.App.Conversation.Ordering.SENT_DATE_ASCENDING), cancellable);
        
        // Add messages.
        if (messages_to_add != null) {
            foreach (Geary.Email email in messages_to_add)
                add_message(email, conversation.is_in_current_folder(email.id));
        }
        
        if (current_folder is Geary.SearchFolder) {
            yield highlight_search_terms();
        } else {
            unhide_last_email();
            if (conversation_list_box.get_children().length() == 1) {
                conversation_list_box.get_children().foreach((child) => {
                    if (child is ConversationWidget) {
                        ((ConversationWidget)child).collapsable = false;
                    }
                });
            }
        }
    }
    
    private void on_search_text_changed(Geary.SearchQuery? query) {
        if (query != null)
            highlight_search_terms.begin();
    }
    
    // This applies a fudge-factor set of matches when the database results
    // aren't entirely satisfactory, such as when you search for an email
    // address and the database tokenizes out the @ and ., etc.  It's not meant
    // to be comprehensive, just a little extra highlighting applied to make
    // the results look a little closer to what you typed.
    private void add_literal_matches(string raw_query, Gee.Set<string>? search_matches) {
        foreach (string word in raw_query.split(" ")) {
            if (word.has_suffix("\""))
                word = word.substring(0, word.length - 1);
            if (word.has_prefix("\""))
                word = word.substring(1);
            
            if (!Geary.String.is_empty_or_whitespace(word))
                search_matches.add(word);
        }
    }
    
    private async void highlight_search_terms() {
        if (search_folder == null)
            return;
        
        // List all IDs of emails we're viewing.
        Gee.Collection<Geary.EmailIdentifier> ids = new Gee.ArrayList<Geary.EmailIdentifier>();
        foreach (Geary.Email email in messages)
            ids.add(email.id);
        
        try {
            Gee.Set<string>? search_matches = yield search_folder.get_search_matches_async(
                ids, cancellable_fetch);
            if (search_matches == null)
                search_matches = new Gee.HashSet<string>();
            
            if (search_folder.search_query != null)
                add_literal_matches(search_folder.search_query.raw, search_matches);
            
            // Webkit's highlighting is ... weird.  In order to actually see
            // all the highlighting you're applying, it seems necessary to
            // start with the shortest string and work up.  If you don't, it
            // seems that shorter strings will overwrite longer ones, and
            // you're left with incomplete highlighting.
            Gee.ArrayList<string> ordered_matches = new Gee.ArrayList<string>();
            ordered_matches.add_all(search_matches);
            ordered_matches.sort((a, b) => a.length - b.length);
            
            conversation_list_box.get_children().foreach((child) => {
                if (!(child is ConversationWidget)) {
                    return;
                }
                
                var webview = ((ConversationWidget) child).webview;
                webview.unmark_text_matches();
                foreach(string match in ordered_matches) {
                    webview.mark_text_matches(match, false, 0);
                }
                
                webview.set_highlight_text_matches(true);
            });
        } catch (Error e) {
            debug("Error highlighting search results: %s", e.message);
        }
    }
    
    // Given some emails, fetch the full versions with all required fields.
    private async Gee.Collection<Geary.Email>? list_full_messages_async(
        Gee.Collection<Geary.Email> emails, Cancellable? cancellable) throws Error {
        Geary.Email.Field required_fields = ConversationViewer.REQUIRED_FIELDS |
            Geary.ComposedEmail.REQUIRED_REPLY_FIELDS;
        
        Gee.ArrayList<Geary.EmailIdentifier> ids = new Gee.ArrayList<Geary.EmailIdentifier>();
        foreach (Geary.Email email in emails)
            ids.add(email.id);
        
        return yield email_store.list_email_by_sparse_id_async(ids, required_fields,
            Geary.Folder.ListFlags.NONE, cancellable);
    }
    
    // Given an email, fetch the full version with all required fields.
    private async Geary.Email fetch_full_message_async(Geary.Email email,
        Cancellable? cancellable) throws Error {
        Geary.Email.Field required_fields = ConversationViewer.REQUIRED_FIELDS |
            Geary.ComposedEmail.REQUIRED_REPLY_FIELDS;
        
        return yield email_store.fetch_email_async(email.id, required_fields,
            Geary.Folder.ListFlags.NONE, cancellable);
    }
    
    // Cancels the current message load, if in progress.
    private void cancel_load() {
        Cancellable old_cancellable = cancellable_fetch;
        cancellable_fetch = new Cancellable();
        
        old_cancellable.cancel();
    }
    
    private void on_conversation_appended(Geary.App.Conversation conversation, Geary.Email email) {
        on_conversation_appended_async.begin(conversation, email, on_conversation_appended_complete);
    }
    
    private async void on_conversation_appended_async(Geary.App.Conversation conversation,
        Geary.Email email) throws Error {
        add_message(yield fetch_full_message_async(email, cancellable_fetch),
            conversation.is_in_current_folder(email.id));
    }
    
    private void on_conversation_appended_complete(Object? source, AsyncResult result) {
        try {
            on_conversation_appended_async.end(result);
        } catch (Error err) {
            debug("Unable to append email to conversation: %s", err.message);
        }
    }
    
    private void on_conversation_trimmed(Geary.Email email) {
        remove_message(email);
    }
    
    private void add_message(Geary.Email email, bool is_in_folder) {
        // Make sure the message container is showing and the multi-message counter hidden.
        set_mode(DisplayMode.CONVERSATION);
        
        if (messages.contains(email))
            return;
        
        messages.add (email);
        
        var message_widget = new ConversationWidget(email, current_folder, is_in_folder);
        message_widget.hovering_over_link.connect((title, url) => on_hovering_over_link(title, url));
        message_widget.link_selected.connect ((link) => {            
            link_selected (link);
        });
        message_widget.mark_read.connect ((read) => {
            if (read) {
                on_mark_read_message (message_widget.email);
            } else {
                on_mark_unread_message (message_widget.email);
            }
        });

        message_widget.star.connect ((star) => {
            if (star) {
                flag_message(message_widget.email);
            } else {
                unflag_message(message_widget.email);
            }
        });

        message_widget.mark_load_remote_images.connect(() => load_remote_images_message(message_widget.email));
        message_widget.open_attachment.connect((attachment) => open_attachment(attachment));
        message_widget.save_attachments.connect((attachments) => save_attachments(attachments));
        message_widget.edit_draft.connect(() => edit_draft(message_widget.email));
        message_widget.reply.connect(() => reply_to_message(message_widget.email));
        message_widget.reply_all.connect(() => reply_all_message(message_widget.email));
        message_widget.forward.connect(() => forward_message(message_widget.email));

        if (email.is_unread() != Geary.Trillian.FALSE) {
            message_widget.collapsed = false;
        }
        
        conversation_list_box.add(message_widget);
        
        message_widget.show_all();
        
        // Add classes according to the state of the email.
        update_flags(email);
    }
    
    private void unhide_last_email() {
        var child = conversation_list_box.get_row_at_index ((int)conversation_list_box.get_children ().length () - 1);
        if (child == null && !(child is ConversationWidget)) {
            return;
        }
        
        ((ConversationWidget) child).collapsed = false;
    }

    private void update_flags(Geary.Email email) {
        Geary.EmailFlags flags = email.email_flags;
        
        // Update the flags in our message set.
        foreach (Geary.Email message in messages) {
            if (message.id.equal_to(email.id)) {
                message.set_flags(flags);
                break;
            }
        }
    }
    
    private void on_mark_read_message(Geary.Email message) {
        Geary.EmailFlags flags = new Geary.EmailFlags();
        flags.add(Geary.EmailFlags.UNREAD);
        mark_messages(Geary.iterate<Geary.EmailIdentifier>(message.id).to_array_list(), null, flags);
    }

    private void on_mark_unread_message(Geary.Email message) {
        Geary.EmailFlags flags = new Geary.EmailFlags();
        flags.add(Geary.EmailFlags.UNREAD);
        mark_messages(Geary.iterate<Geary.EmailIdentifier>(message.id).to_array_list(), flags, null);
    }

    private void load_remote_images_message(Geary.Email message) {
        Geary.EmailFlags flags = new Geary.EmailFlags();
        flags.add(Geary.EmailFlags.LOAD_REMOTE_IMAGES);
        mark_messages(Geary.iterate<Geary.EmailIdentifier>(message.id).to_array_list(), flags, null);
    }
    
    private void flag_message(Geary.Email email) {
        Geary.EmailFlags flags = new Geary.EmailFlags();
        flags.add(Geary.EmailFlags.FLAGGED);
        mark_messages(Geary.iterate<Geary.EmailIdentifier>(email.id).to_array_list(), flags, null);
    }

    private void unflag_message(Geary.Email email) {
        Geary.EmailFlags flags = new Geary.EmailFlags();
        flags.add(Geary.EmailFlags.FLAGGED);
        mark_messages(Geary.iterate<Geary.EmailIdentifier>(email.id).to_array_list(), null, flags);
    }
    
    private void remove_message(Geary.Email email) {
        if (!messages.contains(email))
            return;
        
        conversation_list_box.get_children().foreach((child) => {
            if (!(child is ConversationWidget)) {
                return;
            }
            
            if (((ConversationWidget) child).email.id == email.id) {
                child.destroy();
                messages.remove (email);
            }
        });
    }
    
    private void on_hovering_over_link(string? title, string? url) {
        // Copy the link the user is hovering over.  Note that when the user mouses-out, 
        // this signal is called again with null for both parameters.
        hover_url = url != null ? Uri.unescape_string(url) : null;
        
        if (hover_url == null) {
            message_overlay.hide();
        } else {
            message_overlay.status = hover_url;
            message_overlay.show_all();
        }
    }

    public void show_find_bar() {
        conversation_find_bar.reveal(true);
    }

    public void find(bool forward) {
        if (!conversation_find_bar.child_revealed)
            show_find_bar();
        
        conversation_find_bar.find(forward);
    }      
    
    public void mark_read () {        
        var last_child = conversation_list_box.get_row_at_index ((int)conversation_list_box.get_children ().length () -1);
        var min_value = conversation_scrolled.vadjustment.upper - conversation_scrolled.vadjustment.page_size - last_child.get_allocated_height ();
        stay_down = conversation_scrolled.vadjustment.value >= min_value;
        var start_y = (int) GLib.Math.trunc(conversation_scrolled.vadjustment.value) + READ_MARGIN;
        var view_height = conversation_scrolled.get_allocated_height();
        
        var emails = new Gee.ArrayList<Geary.EmailIdentifier>();
        // Mark all visible widgets of the view as read (if it's considered as visible)
        for (int y = start_y; y < start_y + view_height - 2 * READ_MARGIN; y = y + READ_MARGIN) {
            var row = conversation_list_box.get_row_at_y(y);
            if (row != null && row is ConversationWidget) {
                var email = ((ConversationWidget) row).email;
                if (email.email_flags.is_unread() && !emails.contains(email.id) && !((ConversationWidget) row).forced_unread) {
                    emails.add(email.id);
                }
            }
        }

        if (emails.size > 0) {
            Geary.EmailFlags flags = new Geary.EmailFlags();
            flags.add(Geary.EmailFlags.UNREAD);
            mark_messages(emails, null, flags);
        }
    }
    
    // State reset.
    private uint on_reset(uint state, uint event, void *user, Object? object) {
        conversation_list_box.get_children().foreach((child) => {
            if (!(child is ConversationWidget)) {
                return;
            }
            
            var webview = ((ConversationWidget) child).webview;
            webview.set_highlight_text_matches(true);
            ((ConversationWidget) child).collapsable = true;
            webview.unmark_text_matches();
        });
        
        if (search_folder != null) {
            search_folder.search_query_changed.disconnect(on_search_text_changed);
            search_folder = null;
        }
        
        if (conversation_find_bar.child_revealed)
            fsm.do_post_transition(() => { conversation_find_bar.reveal(false); }, user, object);
        
        return SearchState.NONE;
    }
    
    // Find bar opened.
    private uint on_open_find_bar(uint state, uint event, void *user, Object? object) {
        if (!conversation_find_bar.child_revealed)
            show_find_bar();
        
        allow_collapsing(false);
        
        return SearchState.FIND;
    }
    
    // Find bar closed.
    private uint on_close_find_bar(uint state, uint event, void *user, Object? object) {
        if (current_folder is Geary.SearchFolder) {
            highlight_search_terms.begin();
            
            return SearchState.SEARCH_FOLDER;
        } else {
            allow_collapsing(true);
            
            return SearchState.NONE;
        } 
    }
    
    private void allow_collapsing(bool allow) {
        conversation_list_box.get_children().foreach((child) => {
            ((ConversationWidget) child).collapsable = allow;
        });
    }
    
    // Search folder entered.
    private uint on_enter_search_folder(uint state, uint event, void *user, Object? object) {
        search_folder = current_folder as Geary.SearchFolder;
        assert(search_folder != null);
        search_folder.search_query_changed.connect(on_search_text_changed);
        
        return SearchState.SEARCH_FOLDER;
    }
    
    // Sets the current display mode by displaying only the corresponding DIV.
    private void set_mode(DisplayMode mode) {
        select_conversation_timeout_id = 0; // Cancel select timers.
        
        display_mode = mode;
    }
    
    public void zoom_in() {
        conversation_list_box.get_children().foreach((child) => {
            ((ConversationWidget) child).webview.zoom_in();
        });
    }
    
    public void zoom_out() {
        conversation_list_box.get_children().foreach((child) => {
            ((ConversationWidget) child).webview.zoom_out();
        });
    }
    
    public void zoom_normal() {
        conversation_list_box.get_children().foreach((child) => {
            ((ConversationWidget) child).webview.zoom_level = 1.0f;
        });
    }
}

