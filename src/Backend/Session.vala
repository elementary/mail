// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Mail.Backend.SimpleSasl : Camel.Sasl {
    public SimpleSasl (string service_name, string mechanism, Camel.Service service) {
        Object (service_name: service_name, mechanism: mechanism, service: service);
    }
}

public class Mail.Backend.Session : Camel.Session {
    private static Session _session;
    public static unowned Session get_default () {
        if (_session == null) {
            _session = new Session ();
        }

        return _session;
    }

    E.SourceRegistry registry;
    Gee.LinkedList<Account> accounts;
    //Camel.Store local_store;
    //Camel.Store vfolder_store;

    public signal void account_added (Mail.Backend.Account account);
    public signal void account_removed ();

    private Session () {
        Object (user_data_dir: Path.build_filename (E.get_user_data_dir (), "mail"), user_cache_dir: Path.build_filename (E.get_user_cache_dir (), "mail"));
    }

    construct {
        Camel.init (E.get_user_data_dir (), false);
        accounts = new Gee.LinkedList<Account> ();
        set_network_monitor (E.NetworkMonitor.get_default ());
        set_online (true);
        user_alert.connect ((service, type, message) => { warning (message); });
    }

    public async void start () {
        try {
            registry = yield new E.SourceRegistry (null);
        } catch (Error e) {
            critical (e.message);
            return;
        }

        var sources = registry.list_sources (E.SOURCE_EXTENSION_MAIL_ACCOUNT);
        sources.foreach ((source_item) => {
            unowned string uid = source_item.get_uid ();
            if (uid == "vfolder") {
                return;
            }

            unowned var extension = (E.SourceMailAccount) source_item.get_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT);
            try {
                add_service (uid, extension.backend_name, Camel.ProviderType.STORE);
            } catch (Error e) {
                critical (e.message);
            }
        });
    }

    public override bool authenticate_sync (Camel.Service service, string? mechanism, GLib.Cancellable? cancellable = null) throws GLib.Error {
        /* This function is heavily inspired by mail_ui_session_authenticate_sync in Evolution
         * https://git.gnome.org/browse/evolution/tree/mail/e-mail-ui-session.c */

        /* Do not chain up.  Camel's default method is only an example for
         * subclasses to follow.  Instead we mimic most of its logic here. */

        Camel.ServiceAuthType authtype;
        bool try_empty_password = false;
        var result = Camel.AuthenticationResult.REJECTED;

        if (mechanism == "none") {
            mechanism = null;
        }

        if (mechanism != null) {
            /* APOP is one case where a non-SASL mechanism name is passed, so
             * don't bail if the CamelServiceAuthType struct comes back NULL. */
            authtype = Camel.Sasl.authtype (mechanism);

            /* If the SASL mechanism does not involve a user
             * password, then it gets one shot to authenticate. */
            if (authtype != null && !authtype.need_password) {
                result = service.authenticate_sync (mechanism); //@TODO make async?

                if (result == Camel.AuthenticationResult.REJECTED) {
                    throw new GLib.Error (
                        Camel.Service.error_quark (),
                        Camel.ServiceError.CANT_AUTHENTICATE,
                        "%s authentication failed",
                        mechanism
                    );
                }

                return (result == Camel.AuthenticationResult.ACCEPTED);
            }

            /* Some SASL mechanisms can attempt to authenticate without a
             * user password being provided (e.g. single-sign-on credentials),
             * but can fall back to a user password.  Handle that case next. */
            var sasl = new SimpleSasl (((Camel.Provider)service.provider).protocol, mechanism, service);
            if (sasl != null) {
                try_empty_password = sasl.try_empty_password_sync ();
            }
        }

        /* Find a matching ESource for this CamelService. */
        var source = registry.ref_source (service.get_uid ());

        result = Camel.AuthenticationResult.REJECTED;

        if (try_empty_password) {
            result = service.authenticate_sync (mechanism); //@TODO catch error
        }

        if (result == Camel.AuthenticationResult.REJECTED) {
            /* We need a password, preferrably one cached in
             * the keyring or else by interactive user prompt. */

            var credentials_prompter = new E.CredentialsPrompter (registry);
            credentials_prompter.set_auto_prompt (true);
            return credentials_prompter.loop_prompt_sync (source, E.CredentialsPrompterPromptFlags.ALLOW_SOURCE_SAVE, (prompter, source, credentials, out out_authenticated, cancellable) => try_credentials_sync (prompter, source, credentials, out out_authenticated, cancellable, service, mechanism));
        } else {
            return (result == Camel.AuthenticationResult.ACCEPTED);
        }
    }

    public override bool get_oauth2_access_token_sync (Camel.Service service, out string? access_token, out int expires_in, Cancellable? cancellable = null) throws GLib.Error {
        GLib.Error? local_error = null;

        var source = registry.ref_source (service.get_uid ());
        if (source == null) {
            throw new GLib.IOError.NOT_FOUND ("Corresponding source for service with UID “%s” not found", service.get_uid ());
        }

        var cred_source = registry.find_extension (source, E.SOURCE_EXTENSION_COLLECTION);
        if (cred_source == null || !E.util_can_use_collection_as_credential_source (cred_source, source)) {
            cred_source = source;
        }

        bool success = false;

        try {
            success = cred_source.get_oauth2_access_token_sync (cancellable, out access_token, out expires_in);
        } catch (Error e) {
            local_error = e;

            if (e is GLib.IOError.CONNECTION_REFUSED || e is GLib.IOError.NOT_FOUND) {
                local_error = new GLib.Error (
                    Camel.Service.error_quark (),
                    Camel.ServiceError.CANT_AUTHENTICATE,
                    e.message
                );

                try {
                    if (cred_source.invoke_credentials_required_sync (E.SourceCredentialsReason.REJECTED, "", 0, e)) {
                        local_error = null;
                    }
                } catch (Error invoke_error) {
                    local_error = invoke_error;
                }
            }
        }

        if (local_error != null) {
            throw local_error;
        }

        return success;
    }

    public bool try_credentials_sync (E.CredentialsPrompter prompter, E.Source source, E.NamedParameters credentials, out bool out_authenticated, GLib.Cancellable? cancellable, Camel.Service service, string? mechanism) throws GLib.Error {
        string credential_name = null;

        if (source.has_extension (E.SOURCE_EXTENSION_AUTHENTICATION)) {
            unowned var auth_extension = (E.SourceAuthentication) source.get_extension (E.SOURCE_EXTENSION_AUTHENTICATION);

            credential_name = auth_extension.dup_credential_name ();

            if (credential_name != null && credential_name.length == 0) {
                credential_name = null;
            }
        }

        service.set_password (credentials.get (credential_name ?? E.SOURCE_CREDENTIAL_PASSWORD));

        Camel.AuthenticationResult result = service.authenticate_sync (mechanism); //@TODO catch error

        out_authenticated = (result == Camel.AuthenticationResult.ACCEPTED);

        if (out_authenticated) {
            var credentials_source = prompter.get_provider ().ref_credentials_source (source);

            if (credentials_source != null) {
                credentials_source.invoke_authenticate_sync (credentials);
            }
        }

        return result == Camel.AuthenticationResult.REJECTED;
    }

    public E.Source get_identity_source_for_service (Camel.Service service) {
        var account_source = registry.ref_source (service.get_uid ());
        var account_extension = (E.SourceMailAccount) account_source.get_extension (E.SOURCE_EXTENSION_MAIL_ACCOUNT);
        var identity_uid = account_extension.get_identity_uid ();

        return registry.ref_source (identity_uid);
    }

    public override Camel.Service add_service (string uid, string protocol, Camel.ProviderType type) throws GLib.Error {
        var service = base.add_service (uid, protocol, type);
        if (service is Camel.Service) {
            var source = registry.ref_source (uid);
            unowned string extension_name = E.SourceCamel.get_extension_name (protocol);
            var extension_source = registry.find_extension (source, extension_name);
            if (extension_source != null) {
                source = extension_source;
            }

            /* This handles all the messy property bindings. */
            source.camel_configure_service (service);
            /* Track the proxy resolver for this service. */
            //TODO: mail_session_configure_proxy_resolver (registry, service);
            source.bind_property ("display-name", service, "display-name", BindingFlags.SYNC_CREATE);
            if (service is Camel.OfflineStore) {
                var account = new Account (service);
                accounts.add (account);
                account_added (account);
            }
        }

        return service;
    }

    public override void remove_service (Camel.Service service) {
        base.remove_service (service);
        account_removed ();
    }

    public Gee.LinkedList<Backend.Account> get_accounts () {
        var list = new Gee.LinkedList<Backend.Account> ();
        list.add_all (accounts);
        return list;
    }

    public override unowned Camel.FilterDriver get_filter_driver (string type, Camel.Folder? for_folder) throws Error {
        var filter_driver = new Camel.FilterDriver (this);
        return (Camel.FilterDriver)filter_driver.ref ();
    }

    public Gee.ArrayList<string> get_own_addresses () {
        var addresses = new Gee.ArrayList<string> ();
        var sources = registry.list_enabled (E.SOURCE_EXTENSION_MAIL_IDENTITY);
        sources.foreach ((source_item) => {
            weak E.SourceMailIdentity extension = (E.SourceMailIdentity)source_item.get_extension (E.SOURCE_EXTENSION_MAIL_IDENTITY);
            if (extension == null)
                return;

            var address = extension.get_address ();
            addresses.add (address.casefold ());

            var aliases = extension.get_aliases_as_hash_table ();
            if (aliases != null) {
                aliases.@foreach ((key, val) => {
                    if (!addresses.contains (key.casefold ())) {
                        addresses.add (key.casefold ());
                    }
                });
            }
        });

        return addresses;
    }

    private Camel.Transport? get_camel_transport_from_email (Camel.InternetAddress from) throws GLib.Error {
        var sources = registry.list_enabled (E.SOURCE_EXTENSION_MAIL_IDENTITY);
        foreach (unowned E.Source source_item in sources) {
            weak E.SourceMailIdentity mail_identity = (E.SourceMailIdentity)source_item.get_extension (E.SOURCE_EXTENSION_MAIL_IDENTITY);
            if (source_item.has_extension (E.SOURCE_EXTENSION_MAIL_SUBMISSION)) {
                weak E.SourceMailSubmission mail_submission = (E.SourceMailSubmission)source_item.get_extension (E.SOURCE_EXTENSION_MAIL_SUBMISSION);
                var address = mail_identity.get_address ();
                if (from.find_address (address, null) == 0) {
                    var transport_source = registry.ref_source (mail_submission.transport_uid);
                    weak E.SourceMailTransport mail_transport = (E.SourceMailTransport)transport_source.get_extension (E.SOURCE_EXTENSION_MAIL_TRANSPORT);
                    return add_service (transport_source.uid, mail_transport.backend_name, Camel.ProviderType.TRANSPORT) as Camel.Transport;
                }

                GLib.HashTable<string,string>? aliases = mail_identity.get_aliases_as_hash_table ();
                if (aliases != null) {
                    GLib.List<weak string> aliases_mails = aliases.get_keys ();
                    foreach (weak string key in aliases_mails) {
                        if (from.find_address (key, null) == 0) {
                            var transport_source = registry.ref_source (mail_submission.transport_uid);
                            weak E.SourceMailTransport mail_transport = (E.SourceMailTransport)transport_source.get_extension (E.SOURCE_EXTENSION_MAIL_TRANSPORT);
                            return add_service (transport_source.uid, mail_transport.backend_name, Camel.ProviderType.TRANSPORT) as Camel.Transport;
                        }
                    }
                }
            }
        }

        return null;
    }

    public async void send_email (Camel.MimeMessage message, Camel.InternetAddress from, Camel.Address recipients) {
        Camel.Transport? transport = null;
        try {
            transport = get_camel_transport_from_email (from);
        } catch (Error e) {
            critical (e.message);
            return;
        }

        if (transport == null)
            return;

        try {
            bool sent_message_saved;
            yield transport.connect (GLib.Priority.LOW, null);
            yield transport.send_to (message, from, recipients, GLib.Priority.LOW, null, out sent_message_saved);
            yield transport.disconnect (true, GLib.Priority.LOW, null);
        } catch (Error e) {
            critical (e.message);
        }

        remove_service (transport);
    }
}
