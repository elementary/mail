// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016 elementary LLC. (https://elementary.io)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Geary.OnlineAccountsWrapper : GLib.Object {
    private Ag.Manager manager;
    public OnlineAccountsWrapper () {
        manager = new Ag.Manager.for_service_type ("mail");
        manager.get_account_services ().foreach ((account_service) => {
            if (account_service.get_enabled ()) {
                add_accountservice.begin (account_service);
            } else {
                remove_accountservice.begin (account_service);
            }

            account_service.enabled.connect ((enabled) => {
                if (enabled) {
                    add_accountservice.begin (account_service);
                } else {
                    remove_accountservice.begin (account_service);
                }
            });
        });
    }

    private async void add_accountservice (Ag.AccountService account_service) {
        var auth_data = account_service.get_auth_data ();
        Geary.AccountInformation account_information;
        var session_data = auth_data.get_login_parameters (null);
        var user_name = account_service.account.display_name;
        try {
            var identity = new Signon.Identity.from_db (auth_data.get_credentials_id ());
            var session = identity.create_session (auth_data.get_method ());
            var result = yield session.process (session_data, auth_data.get_mechanism (), null);
            var secret = result.lookup_value ("Secret", null).dup_string ();
            account_information = Geary.Engine.instance.get_accounts ().get (user_name);
            if (account_information == null) {
                account_information = Geary.Engine.instance.create_orphan_account (user_name);
            }

            if (auth_data.get_method () == "mail") {
                yield add_mail_account (result, account_information);
            } else {
                account_information.imap_credentials = new Geary.Credentials (user_name, secret);
                account_information.smtp_credentials = new Geary.Credentials (user_name, secret);
                yield add_password_account (account_service, account_information);
            }
        } catch (Error err) {
            debug("Unable to open account information for %s: %s", user_name, err.message);
            return;
        }


        string real_name = Environment.get_real_name();
        var actual_real_name = account_information.real_name;
        if (actual_real_name == null || actual_real_name == "") {
            account_information.real_name = real_name == "Unknown" ? "" : real_name;
        }

        var actual_nickname = account_information.nickname;
        if (actual_nickname == null || actual_nickname == "") {
            account_information.nickname = user_name;
        }

        account_information.imap_remember_password = true;
        account_information.smtp_remember_password = true;
        account_information.service_provider = Geary.ServiceProvider.OTHER;
        account_information.save_sent_mail = true;
        account_information.default_smtp_use_imap_credentials = false;
        account_information.prefetch_period_days = Geary.AccountInformation.DEFAULT_PREFETCH_PERIOD_DAYS;
        account_information.save_drafts = true;
        account_information.use_email_signature = false;
        account_information.email_signature = null;
        try {
            yield account_information.store_async (null);
            yield account_information.update_stored_passwords_async (Geary.ServiceFlag.IMAP | Geary.ServiceFlag.SMTP);
        } catch (Error e) {
            debug("Error updating stored passwords: %s", e.message);
        }
    }

    private async void add_password_account (Ag.AccountService account_service, Geary.AccountInformation account_information) {
        var imap_server_name = account_service.get_variant ("Configuration/IMAP/Server", null);
        if (imap_server_name == null) {
            return;
        }

        var imap_server_port = account_service.get_variant ("Configuration/IMAP/Port", null);
        var imap_security = account_service.get_variant ("Configuration/IMAP/Security", null);
        if (imap_security != null) {
            var imap_sec = imap_security.get_string ();
            account_information.default_imap_server_ssl = "SSL/TLS" in imap_sec;
            account_information.default_imap_server_starttls = "STARTTLS" in imap_sec;
        } else {
            account_information.default_imap_server_ssl = false;
            account_information.default_imap_server_starttls = false;
        }

        var smtp_server_name = account_service.get_variant ("Configuration/SMTP/Server", null);
        if (smtp_server_name == null) {
            return;
        }

        var smtp_server_port = account_service.get_variant ("Configuration/SMTP/Port", null);
        var smtp_security = account_service.get_variant ("Configuration/SMTP/Security", null);
        if (smtp_security != null) {
            var smtp_sec = smtp_security.get_string ();
            account_information.default_smtp_server_ssl = "SSL/TLS" in smtp_sec;
            account_information.default_smtp_server_starttls = "STARTTLS" in smtp_sec;
        } else {
            account_information.default_smtp_server_ssl = false;
            account_information.default_smtp_server_starttls = false;
        }

        var smtp_no_auth = account_service.get_variant ("Configuration/SMTP/NoAuth", null);
        if (smtp_no_auth != null) {
            account_information.default_smtp_server_noauth = smtp_no_auth.get_boolean ();
        } else {
            account_information.default_smtp_server_noauth = false;
        }

        account_information.default_imap_server_host = imap_server_name.get_string ();
        account_information.default_imap_server_port = imap_server_port != null ? imap_server_port.get_uint16 () : Geary.Imap.ClientConnection.DEFAULT_PORT_SSL;
        account_information.default_smtp_server_host = smtp_server_name.get_string ();
        account_information.default_smtp_server_port = smtp_server_port != null ? smtp_server_port.get_uint16 () : Geary.Smtp.ClientConnection.DEFAULT_PORT_STARTTLS;
    }

    private async void add_mail_account (Variant result, Geary.AccountInformation account_information) {
        var imap_server_name = result.lookup_value ("ImapServer", null);
        if (imap_server_name == null) {
            return;
        }

        var imap_server_port = result.lookup_value ("ImapPort", null);
        var imap_security = result.lookup_value ("ImapSecurity", null);
        if (imap_security != null) {
            var imap_sec = imap_security.get_string ();
            account_information.default_imap_server_ssl = "SSL/TLS" in imap_sec;
            account_information.default_imap_server_starttls = "STARTTLS" in imap_sec;
        } else {
            account_information.default_imap_server_ssl = false;
            account_information.default_imap_server_starttls = false;
        }

        var imap_user = result.lookup_value ("ImapUser", null).dup_string ();
        var imap_password = result.lookup_value ("ImapPassword", null).dup_string ();
        account_information.imap_credentials = new Geary.Credentials (imap_user, imap_password);

        var smtp_server_name = result.lookup_value ("SmtpServer", null);
        if (smtp_server_name == null) {
            return;
        }

        var smtp_server_port = result.lookup_value ("SmtpPort", null);
        var smtp_security = result.lookup_value ("SmtpSecurity", null);
        if (smtp_security != null) {
            var smtp_sec = smtp_security.get_string ();
            account_information.default_smtp_server_ssl = "SSL/TLS" in smtp_sec;
            account_information.default_smtp_server_starttls = "STARTTLS" in smtp_sec;
        } else {
            account_information.default_smtp_server_ssl = false;
            account_information.default_smtp_server_starttls = false;
        }

        var smtp_user = result.lookup_value ("SmtpUser", null);
        var smtp_password = result.lookup_value ("SmtpPassword", null);
        if (smtp_user == null || smtp_password == null) {
            account_information.default_smtp_server_noauth = true;
        } else {
            account_information.default_smtp_server_noauth = false;
            account_information.smtp_credentials = new Geary.Credentials (smtp_user.get_string (), smtp_password.get_string ());
        }

        account_information.default_imap_server_host = imap_server_name.get_string ();
        account_information.default_imap_server_port = Geary.Imap.ClientConnection.DEFAULT_PORT_SSL;
        if (imap_server_port != null) {
            account_information.default_imap_server_port = imap_server_port.get_uint16 ();
        }

        account_information.default_smtp_server_host = smtp_server_name.get_string ();
        account_information.default_smtp_server_port = Geary.Smtp.ClientConnection.DEFAULT_PORT_STARTTLS;
        if (smtp_server_port != null) {
            account_information.default_smtp_server_port = smtp_server_port.get_uint16 ();
        }
    }

    private async void remove_accountservice (Ag.AccountService account_service) {
        try {
            var user_name = account_service.account.display_name;
            var account_information = Geary.Engine.instance.get_accounts ().get (user_name);
            if (account_information != null) {
                var account_instance = Geary.Engine.instance.get_account_instance (account_information);
                yield account_instance.close_async (null);
                yield account_information.remove_async (null);
            }
        } catch (Error e) {
            debug("Error updating stored passwords: %s", e.message);
        }
    }
}
