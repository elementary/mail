/* Copyright 2011-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

// Stores formatted data for a message.
public class FormattedConversationData : Geary.BaseObject {
    public const int LINE_SPACING = 6;
    
    private const string ME = _("Me");
    private const string STYLE_EXAMPLE = "Gg"; // Use both upper and lower case to get max height.
    private const int LEFT_ICON_SIZE = 16;
    private const int TEXT_LEFT = LINE_SPACING * 2;
    private const double DIM_TEXT_AMOUNT = 0.05;
    private const double DIM_PREVIEW_TEXT_AMOUNT = 0.25;
    
    private const int FONT_SIZE_DATE = 10;
    private const int FONT_SIZE_SUBJECT = 9;
    private const int FONT_SIZE_FROM = 11;
    private const int FONT_SIZE_PREVIEW = 8;
    
    private class ParticipantDisplay : Geary.BaseObject, Gee.Hashable<ParticipantDisplay> {
        public Geary.RFC822.MailboxAddress address;
        public bool is_unread;
        
        public ParticipantDisplay(Geary.RFC822.MailboxAddress address, bool is_unread) {
            this.address = address;
            this.is_unread = is_unread;
        }
        
        public string get_full_markup(Gee.List<Geary.RFC822.MailboxAddress> account_mailboxes) {
            return get_as_markup((address in account_mailboxes) ? ME : address.get_short_address());
        }
        
        public string get_short_markup(Gee.List<Geary.RFC822.MailboxAddress> account_mailboxes) {
            if (address in account_mailboxes)
                return get_as_markup(ME);
            
            string short_address = address.get_short_address().strip();
            
            if (", " in short_address) {
                // assume address is in Last, First format
                string[] tokens = short_address.split(", ", 2);
                short_address = tokens[1].strip();
                if (Geary.String.is_empty(short_address))
                    return get_full_markup(account_mailboxes);
            }
            
            // use first name as delimited by a space
            string[] tokens = short_address.split(" ", 2);
            if (tokens.length < 1)
                return get_full_markup(account_mailboxes);
            
            string first_name = tokens[0].strip();
            if (Geary.String.is_empty_or_whitespace(first_name))
                return get_full_markup(account_mailboxes);
            
            return get_as_markup(first_name);
        }
        
        private string get_as_markup(string participant) {
            return "%s%s%s".printf(
                is_unread ? "<b>" : "", Geary.HTML.escape_markup(participant), is_unread ? "</b>" : "");
        }
        
        public bool equal_to(ParticipantDisplay other) {
            return address.equal_to(other.address);
        }
        
        public uint hash() {
            return address.hash();
        }
    }
    
    private static int cell_height = -1;
    private static int preview_height = -1;
    
    public bool is_unread { get; set; }
    public bool is_flagged { get; set; }
    public string date { get; private set; }
    public string subject { get; private set; }
    public string? body { get; private set; default = null; } // optional
    public int num_emails { get; set; }
    public Geary.Email? preview { get; private set; default = null; }
    
    private Geary.App.Conversation? conversation = null;
    private Gee.List<Geary.RFC822.MailboxAddress>? account_owner_emails = null;
    private bool use_to = true;
    private CountBadge count_badge = new CountBadge(2);
    private Gdk.Pixbuf read_pixbuf = null;
    private Gdk.Pixbuf unread_pixbuf = null;
    private Gdk.Pixbuf starred_pixbuf = null;
    private Gdk.Pixbuf unstarred_pixbuf = null;
    private int current_scale_factor = 1;
    
    // Creates a formatted message data from an e-mail.
    public FormattedConversationData(Geary.App.Conversation conversation, Geary.Email preview,
        Geary.Folder folder, Gee.List<Geary.RFC822.MailboxAddress> account_owner_emails) {
        assert(preview.fields.fulfills(ConversationListStore.REQUIRED_FIELDS));
        
        this.conversation = conversation;
        this.account_owner_emails = account_owner_emails;
        use_to = (folder != null) && folder.special_folder_type.is_outgoing();
        
        // Load preview-related data.
        update_date_string();
        this.subject = EmailUtil.strip_subject_prefixes(preview);
        this.body = Geary.String.reduce_whitespace(preview.get_preview_as_string());
        this.preview = preview;
        
        // Load conversation-related data.
        this.is_unread = conversation.is_unread();
        this.is_flagged = conversation.is_flagged();
        this.num_emails = conversation.get_count();
    }
    
    public bool update_date_string() {
        // get latest email *in folder* for the conversation's date, fall back on out-of-folder
        Geary.Email? latest = conversation.get_latest_recv_email(Geary.App.Conversation.Location.IN_FOLDER_OUT_OF_FOLDER);
        if (latest == null || latest.properties == null)
            return false;
        
        // conversation list store sorts by date-received, so display that instead of sender's
        // Date:
        string new_date = Date.pretty_print(latest.properties.date_received,
            GearyApplication.instance.config.clock_format);
        if (new_date == date)
            return false;
        
        date = new_date;
        
        return true;
    }
    
    // Creates an example message (used interally for styling calculations.)
    public FormattedConversationData.create_example() {
        this.is_unread = false;
        this.is_flagged = false;
        this.date = STYLE_EXAMPLE;
        this.subject = STYLE_EXAMPLE;
        this.body = STYLE_EXAMPLE + "\n" + STYLE_EXAMPLE;
        this.num_emails = 1;
    }
    
    private string get_participants_markup(Gtk.Widget widget, bool selected) {
        if (conversation == null || account_owner_emails == null || account_owner_emails.size == 0)
            return "";
        
        // Build chronological list of AuthorDisplay records, setting to unread if any message by
        // that author is unread
        Gee.ArrayList<ParticipantDisplay> list = new Gee.ArrayList<ParticipantDisplay>();
        foreach (Geary.Email message in conversation.get_emails(Geary.App.Conversation.Ordering.RECV_DATE_ASCENDING)) {
            // only display if something to display
            Geary.RFC822.MailboxAddresses? addresses = use_to ? message.to : message.from;
            if (addresses == null || addresses.size < 1)
                continue;
            
            foreach (Geary.RFC822.MailboxAddress address in addresses) {
                ParticipantDisplay participant_display = new ParticipantDisplay(address,
                    message.email_flags.is_unread());

                // if not present, add in chronological order
                int existing_index = list.index_of(participant_display);
                if (existing_index < 0) {
                    list.add(participant_display);

                    continue;
                }
                
                // if present and this message is unread but the prior were read,
                // this author is now unread
                if (message.email_flags.is_unread() && !list[existing_index].is_unread)
                    list[existing_index].is_unread = true;
            }
        }
        
        StringBuilder builder = new StringBuilder();
        if (list.size == 1) {
            // if only one participant, use full name
            builder.append(list[0].get_full_markup(account_owner_emails));
        } else {
            bool first = true;
            foreach (ParticipantDisplay participant in list) {
                if (!first) {
                    if (widget.get_direction() == Gtk.TextDirection.RTL) {
                        ///Translators: this is the ponctuation between two names ("John, Jane")
                        builder.prepend(_(", "));
                    } else {
                        builder.append(_(", "));
                    }
                }
                
                if (widget.get_direction() == Gtk.TextDirection.RTL) {
                    builder.prepend(participant.get_short_markup(account_owner_emails));
                } else {
                    builder.append(participant.get_short_markup(account_owner_emails));
                }
                first = false;
            }
        }
        
        return builder.str;
    }
    
    public void render(Cairo.Context ctx, Gtk.Widget widget, Gdk.Rectangle background_area, 
        Gdk.Rectangle cell_area, Gtk.CellRendererState flags, bool hover_select) {
        render_internal(widget, cell_area, ctx, flags, false, hover_select);
    }
    
    // Call this on style changes.
    public void calculate_sizes(Gtk.Widget widget) {
        render_internal(widget, null, null, 0, true, false);
    }
    
    // Must call calculate_sizes() first.
    public void get_size(Gtk.Widget widget, Gdk.Rectangle? cell_area, out int x_offset, 
        out int y_offset, out int width, out int height) {
        assert(cell_height != -1); // ensures calculate_sizes() was called.
        
        x_offset = 0;
        y_offset = 0;
        // set width to 1 (rather than 0) to work around certain themes that cause the
        // conversation list to be shown as "squished":
        // https://bugzilla.gnome.org/show_bug.cgi?id=713954
        width = 1;
        height = cell_height;
    }
    
    // Can be used for rendering or calculating height.
    private void render_internal(Gtk.Widget widget, Gdk.Rectangle? cell_area, 
        Cairo.Context? ctx, Gtk.CellRendererState flags, bool recalc_dims,
        bool hover_select) {
        bool display_preview = GearyApplication.instance.config.display_preview;
        int y = LINE_SPACING + (cell_area != null ? cell_area.y : 0);
        
        bool selected = (flags & Gtk.CellRendererState.SELECTED) != 0;
        bool hover = (flags & Gtk.CellRendererState.PRELIT) != 0 || (selected && hover_select);
        
        // Date field.
        Pango.Rectangle ink_rect = render_date(widget, cell_area, ctx, y, selected);

        // From field.
        ink_rect = render_from(widget, cell_area, ctx, y, selected, ink_rect);
        y += ink_rect.height + ink_rect.y + LINE_SPACING;

        // If we are displaying a preview then the message counter goes on the same line as the
        // preview, otherwise it is with the subject.
        int preview_height = 0;
        
        // Setup counter badge.
        count_badge.count = num_emails;
        int counter_width = count_badge.get_width(widget) + LINE_SPACING;
        int counter_x = cell_area != null ? cell_area.width - cell_area.x - counter_width +
            (LINE_SPACING / 2) : 0;
        
        if (display_preview) {
            // Subject field.
            render_subject(widget, cell_area, ctx, y, selected);
            y += ink_rect.height + ink_rect.y + LINE_SPACING;
            
            // Number of e-mails field.
            count_badge.render(widget, ctx, counter_x, y, selected);
            
            // Body preview.
            ink_rect = render_preview(widget, cell_area, ctx, y, selected, counter_width);
            preview_height = ink_rect.height + ink_rect.y + LINE_SPACING;
        } else {
            // Number of e-mails field.
            count_badge.render(widget, ctx, counter_x, y, selected);
            
            // Subject field.
            render_subject(widget, cell_area, ctx, y, selected, counter_width);
            y += ink_rect.height + ink_rect.y + LINE_SPACING;
        }

        if (recalc_dims) {
            FormattedConversationData.preview_height = preview_height;
            FormattedConversationData.cell_height = y + preview_height;
        } else {
            int unread_y = display_preview ? cell_area.y + LINE_SPACING * 2 : cell_area.y +
                LINE_SPACING;
            
            var style_context = widget.get_style_context();
            if (current_scale_factor != widget.get_scale_factor ()) {
                read_pixbuf = null;
                unread_pixbuf = null;
                starred_pixbuf = null;
                unstarred_pixbuf = null;
            }
            // Unread indicator.
            if (is_unread || hover) {
                var read_icon = get_read_pixbuf(widget, is_unread);
                if (read_icon != null) {
                    style_context.render_icon(ctx, read_icon, cell_area.x + LINE_SPACING, unread_y);
                }
            }
            
            // Starred indicator.
            if (is_flagged || hover) {
                var starred_icon = get_starred_pixbuf(widget, is_flagged);
                int star_y = cell_area.y + (cell_area.height / 2) + (display_preview ? LINE_SPACING : 0);
                if (starred_icon != null) {
                    style_context.render_icon(ctx, starred_icon, cell_area.x + LINE_SPACING, star_y);
                }
            }
        }
    }
    
    private Pango.Rectangle render_date(Gtk.Widget widget, Gdk.Rectangle? cell_area,
        Cairo.Context? ctx, int y, bool selected) {
        Pango.Rectangle? ink_rect;
        Pango.Rectangle? logical_rect;
        Pango.Layout layout_date = widget.create_pango_layout(null);
        var font_date = layout_date.get_context ().get_font_description ();
        font_date.set_size(FONT_SIZE_DATE * Pango.SCALE);
        layout_date.set_font_description(font_date);
        layout_date.set_markup(Geary.HTML.escape_markup(date), -1);
        if (widget.get_direction() == Gtk.TextDirection.RTL) {
            layout_date.set_alignment(Pango.Alignment.LEFT);
        } else {
            layout_date.set_alignment(Pango.Alignment.RIGHT);
        }

        layout_date.get_pixel_extents(out ink_rect, out logical_rect);
        if (ctx != null && cell_area != null) {
            widget.get_style_context ().render_layout (ctx, cell_area.width - cell_area.x - ink_rect.width - ink_rect.x - LINE_SPACING, y, layout_date);
        }
        return ink_rect;
    }
    
    private Pango.Rectangle render_from(Gtk.Widget widget, Gdk.Rectangle? cell_area,
        Cairo.Context? ctx, int y, bool selected, Pango.Rectangle ink_rect) {
        string from_markup = (conversation != null) ? get_participants_markup(widget, selected) : STYLE_EXAMPLE;
        
        Pango.FontDescription font_from = new Pango.FontDescription();
        font_from.set_size(FONT_SIZE_FROM * Pango.SCALE);
        Pango.Layout layout_from = widget.create_pango_layout(null);
        layout_from.set_font_description(font_from);
        layout_from.set_markup(from_markup, -1);
        if (widget.get_direction() == Gtk.TextDirection.RTL) {
            layout_from.set_ellipsize(Pango.EllipsizeMode.START);
        } else {
            layout_from.set_ellipsize(Pango.EllipsizeMode.END);
        }
        if (ctx != null && cell_area != null) {
            layout_from.set_width((cell_area.width - ink_rect.width - ink_rect.x - (LINE_SPACING * 3) -
                TEXT_LEFT - LEFT_ICON_SIZE * widget.get_scale_factor())
            * Pango.SCALE);
            widget.get_style_context ().render_layout (ctx, cell_area.x + TEXT_LEFT + LEFT_ICON_SIZE * widget.get_scale_factor(), y, layout_from);
        }
        return ink_rect;
    }
    
    private void render_subject(Gtk.Widget widget, Gdk.Rectangle? cell_area, Cairo.Context? ctx,
        int y, bool selected, int counter_width = 0) {
        
        Pango.FontDescription font_subject = new Pango.FontDescription();
        font_subject.set_size(FONT_SIZE_SUBJECT * Pango.SCALE);
        if (is_unread)
            font_subject.set_weight(Pango.Weight.BOLD);
        Pango.Layout layout_subject = widget.create_pango_layout(null);
        layout_subject.set_font_description(font_subject);
        layout_subject.set_markup(Geary.HTML.escape_markup(subject), -1);
        if (cell_area != null)
            layout_subject.set_width((cell_area.width - TEXT_LEFT - LEFT_ICON_SIZE * widget.get_scale_factor() - counter_width) * Pango.SCALE);

        if (widget.get_direction() == Gtk.TextDirection.RTL) {
            layout_subject.set_ellipsize(Pango.EllipsizeMode.START);
        } else {
            layout_subject.set_ellipsize(Pango.EllipsizeMode.END);
        }

        if (ctx != null && cell_area != null) {
            widget.get_style_context ().render_layout (ctx, cell_area.x + TEXT_LEFT + LEFT_ICON_SIZE * widget.get_scale_factor(), y, layout_subject);
        }
    }
    
    private Pango.Rectangle render_preview(Gtk.Widget widget, Gdk.Rectangle? cell_area,
        Cairo.Context? ctx, int y, bool selected, int counter_width = 0) {
        var style_context = widget.get_style_context ();
        style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        Pango.Layout layout_preview = widget.create_pango_layout(null);
        var font_preview = layout_preview.get_context ().get_font_description ();
        font_preview.set_size(FONT_SIZE_PREVIEW * Pango.SCALE);
        layout_preview.set_font_description(font_preview);
        
        layout_preview.set_markup(Geary.String.is_empty(body) ? "" : Geary.HTML.escape_markup(body), -1);
        layout_preview.set_wrap(Pango.WrapMode.WORD);
        if (widget.get_direction() == Gtk.TextDirection.RTL) {
            layout_preview.set_ellipsize(Pango.EllipsizeMode.START);
        } else {
            layout_preview.set_ellipsize(Pango.EllipsizeMode.END);
        }
        if (ctx != null && cell_area != null) {
            layout_preview.set_width((cell_area.width - TEXT_LEFT - LEFT_ICON_SIZE * widget.get_scale_factor() - counter_width - LINE_SPACING) * Pango.SCALE);
            layout_preview.set_height(preview_height * Pango.SCALE);
            
            style_context.render_layout (ctx, cell_area.x + TEXT_LEFT + LEFT_ICON_SIZE * widget.get_scale_factor(), y, layout_preview);
        } else {
            layout_preview.set_width(int.MAX);
            layout_preview.set_height(int.MAX);
        }

        style_context.remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
        Pango.Rectangle? ink_rect;
        Pango.Rectangle? logical_rect;
        layout_preview.get_pixel_extents(out ink_rect, out logical_rect);
        return ink_rect;
    }
    
    private Gdk.Pixbuf? get_read_pixbuf (Gtk.Widget widget, bool is_unread) {
        if (is_unread) {
            if (unread_pixbuf == null) {
                var icon_theme = Gtk.IconTheme.get_default();
                var style_context = widget.get_style_context();
                var icon_info = icon_theme.lookup_icon_for_scale("mail-unread-symbolic", LEFT_ICON_SIZE, widget.get_scale_factor(), Gtk.IconLookupFlags.GENERIC_FALLBACK|Gtk.IconLookupFlags.FORCE_SIZE);
                if (icon_info != null) {
                    try {
                        unread_pixbuf = icon_info.load_symbolic_for_context(style_context);
                    } catch (Error e) {
                        critical (e.message);
                    }
                }
            }

            return unread_pixbuf;
        } else {
            if (read_pixbuf == null) {
                var icon_theme = Gtk.IconTheme.get_default();
                var style_context = widget.get_style_context();
                var icon_info = icon_theme.lookup_icon_for_scale("mail-read-symbolic", LEFT_ICON_SIZE, widget.get_scale_factor(), Gtk.IconLookupFlags.GENERIC_FALLBACK|Gtk.IconLookupFlags.FORCE_SIZE);
                if (icon_info != null) {
                    try {
                        read_pixbuf = icon_info.load_symbolic_for_context(style_context);
                    } catch (Error e) {
                        critical (e.message);
                    }
                }
            }

            return read_pixbuf;
        }
    }
    
    private Gdk.Pixbuf? get_starred_pixbuf (Gtk.Widget widget, bool is_starred) {
        if (is_starred) {
            if (starred_pixbuf == null) {
                var icon_theme = Gtk.IconTheme.get_default();
                var style_context = widget.get_style_context();
                var icon_info = icon_theme.lookup_icon_for_scale("starred-symbolic", LEFT_ICON_SIZE, widget.get_scale_factor(), Gtk.IconLookupFlags.GENERIC_FALLBACK|Gtk.IconLookupFlags.FORCE_SIZE);
                if (icon_info != null) {
                    try {
                        starred_pixbuf = icon_info.load_symbolic_for_context(style_context);
                    } catch (Error e) {
                        critical (e.message);
                    }
                }
            }

            return starred_pixbuf;
        } else {
            if (unstarred_pixbuf == null) {
                var icon_theme = Gtk.IconTheme.get_default();
                var style_context = widget.get_style_context();
                var icon_info = icon_theme.lookup_icon_for_scale("non-starred-symbolic", LEFT_ICON_SIZE, widget.get_scale_factor(), Gtk.IconLookupFlags.GENERIC_FALLBACK|Gtk.IconLookupFlags.FORCE_SIZE);
                if (icon_info != null) {
                    try {
                        unstarred_pixbuf = icon_info.load_symbolic_for_context(style_context);
                    } catch (Error e) {
                        critical (e.message);
                    }
                }
            }

            return unstarred_pixbuf;
        }
    }
}

