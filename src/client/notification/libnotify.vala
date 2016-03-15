/* Copyright 2011-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

// Displays a notification via libnotify
public class Libnotify : Geary.BaseObject {
    public const Geary.Email.Field REQUIRED_FIELDS =
        Geary.Email.Field.ORIGINATORS | Geary.Email.Field.SUBJECT;
    private static Canberra.Context? sound_context = null;
    
    private NewMessagesMonitor monitor;
    private bool visible_notification = false;
    private bool visible_error = false;
    private Geary.Folder? folder = null;
    private Geary.Email? email = null;
    
    public signal void invoked(Geary.Folder? folder, Geary.Email? email);
    
    public Libnotify(NewMessagesMonitor monitor) {
        this.monitor = monitor;
        monitor.add_required_fields(REQUIRED_FIELDS);
        monitor.new_messages_arrived.connect(on_new_messages_arrived);
    }
    
    private void on_new_messages_arrived(Geary.Folder folder, int total, int added) {
        if (added == 1 && monitor.last_new_message_folder != null &&
            monitor.last_new_message != null) {
            notify_one_message_async.begin(monitor.last_new_message_folder,
                monitor.last_new_message, null);
        } else if (added > 0) {
            notify_new_mail(folder, added);
        }
    }
    
    private void notify_new_mail(Geary.Folder folder, int added) {
        // don't pass email if invoked
        this.folder = null;
        email = null;
        
        if (!monitor.should_notify_new_messages(folder))
            return;
        
        string body = ngettext("%d new message", "%d new messages", added).printf(added);
        int total = monitor.get_new_message_count(folder);
        if (total > added) {
            body = ngettext("%s, %d new message total", "%s, %d new messages total", total).printf(
                body, total);
        }
        
        issue_current_notification(folder.account.information.email, body, null);
    }
    
    private async void notify_one_message_async(Geary.Folder folder, Geary.Email email,
        GLib.Cancellable? cancellable) throws GLib.Error {
        assert(email.fields.fulfills(REQUIRED_FIELDS));
        
        // used if notification is invoked
        this.folder = folder;
        this.email = email;
        
        if (!monitor.should_notify_new_messages(folder))
            return;

        // possible to receive email with no originator
        Geary.RFC822.MailboxAddress? primary = email.get_primary_originator();
        if (primary == null) {
            notify_new_mail(folder, 1);
            
            return;
        }
        
        string body = EmailUtil.strip_subject_prefixes(email);
        // get the avatar
        var avatar_file = File.new_for_uri (Gravatar.get_image_uri(primary, Gravatar.Default.NOT_FOUND));
        GLib.Icon icon = null;
        try {
            FileIOStream iostream;
            var file = File.new_tmp("geary-contact-XXXXXX.png", out iostream);
            iostream.close();
            avatar_file.copy(file, GLib.FileCopyFlags.OVERWRITE);
            icon = new FileIcon(file);
        } catch (Error e) {
            critical (e.message);
        }

        issue_current_notification(primary.get_short_address(), body, icon);
    }
    
    private void issue_current_notification(string summary, string body, GLib.Icon? icon) {
        // only one outstanding notification at a time
        if (visible_notification) {
            GearyApplication.instance.withdraw_notification ("email.arrived");
            visible_notification = false;
        }
        
        var notification = new Notification(summary);
        notification.set_body(body);
        notification.set_icon(icon ?? new ThemedIcon("internet-mail"));
        notification.set_default_action ("app.go-to-notification");
        GearyApplication.instance.send_notification ("email.arrived", notification);
    }
    
    public void set_error_notification(string summary, string body) {
        // Only one error at a time, guys.  (This means subsequent errors will
        // be dropped.  Since this is only used for one thing now, that's ok,
        // but it means in the future, a more robust system will be needed.)
        if (visible_error)
            return;
        
        var notification = new Notification(summary);
        notification.set_body(body);
        GearyApplication.instance.send_notification ("email.error", notification);
        visible_error = true;
    }
    
    public void clear_error_notification() {
        GearyApplication.instance.withdraw_notification ("email.error");
        visible_error = false;
    }
    
    public void notification_clicked() {
        invoked(folder, email);
    }
    
    private static void init_sound() {
        if (sound_context == null)
            Canberra.Context.create(out sound_context);
    }
    
    public static void play_sound(string sound) {
        init_sound();
        sound_context.play(0, Canberra.PROP_EVENT_ID, sound);
    }
}

