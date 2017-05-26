/* Copyright 2011-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class Geary.ComposedEmail : BaseObject {
    public const string MAILTO_SCHEME = "mailto:";

    private const string IMG_SRC_TEMPLATE = "src=\"%s\"";
    
    public const Geary.Email.Field REQUIRED_REPLY_FIELDS =
        Geary.Email.Field.HEADER
        | Geary.Email.Field.BODY
        | Geary.Email.Field.ORIGINATORS
        | Geary.Email.Field.RECEIVERS
        | Geary.Email.Field.REFERENCES
        | Geary.Email.Field.SUBJECT
        | Geary.Email.Field.DATE;
    
    public DateTime date { get; set; }
    // TODO: sender goes here, but not beyond, as it's not properly supported by GMime yet.
    public RFC822.MailboxAddress? sender { get; set; default = null; }
    public RFC822.MailboxAddresses from { get; set; }
    public RFC822.MailboxAddresses? to { get; set; default = null; }
    public RFC822.MailboxAddresses? cc { get; set; default = null; }
    public RFC822.MailboxAddresses? bcc { get; set; default = null; }
    public RFC822.MailboxAddresses? reply_to { get; set; default = null; }
    public string? in_reply_to { get; set; default = null; }
    public Geary.Email? reply_to_email { get; set; default = null; }
    public string? references { get; set; default = null; }
    public string? subject { get; set; default = null; }
    public string? body_text { get; set; default = null; }
    public string? body_html { get; set; default = null; }
    public string? mailer { get; set; default = null; }

    public Gee.Set<File> attached_files { get; private set;
        default = new Gee.HashSet<File> (Geary.Files.nullable_hash, Geary.Files.nullable_equal); }
    public Gee.Set<File> inline_files { get; private set;
        default = new Gee.HashSet<File> (Geary.Files.nullable_hash, Geary.Files.nullable_equal); }
    public Gee.Map<string,File> cid_files = new Gee.HashMap<string,File> ();

    public string img_src_prefix { get; set; default = ""; }
    
    public ComposedEmail(DateTime date, RFC822.MailboxAddresses from, 
        RFC822.MailboxAddresses? to = null, RFC822.MailboxAddresses? cc = null,
        RFC822.MailboxAddresses? bcc = null, string? subject = null,
        string? body_text = null, string? body_html = null) {
        this.date = date;
        this.from = from;
        this.to = to;
        this.cc = cc;
        this.bcc = bcc;
        this.subject = subject;
        this.body_text = body_text;
        this.body_html = body_html;
    }
    
    public Geary.RFC822.Message to_rfc822_message(string? message_id = null) {
        return new RFC822.Message.from_composed_email (this, message_id);
    }

    public bool contains_inline_img_src (string value) {
        return body_html.contains (IMG_SRC_TEMPLATE.printf (value));
    }

    public bool replace_inline_img_src (string orig, string replacement) {
        bool ret = false;
        if (body_html != null) {
            string old_body = body_html;
            body_html = old_body.replace (
                IMG_SRC_TEMPLATE.printf (img_src_prefix + orig),
                IMG_SRC_TEMPLATE.printf (replacement)
            );
            ret = body_html.length != old_body.length;
        }
        return ret;
    }
}

