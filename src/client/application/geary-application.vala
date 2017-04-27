/* Copyright 2011-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

// Defined by CMake build script.
extern const string _VERSION;
extern const string _INSTALL_PREFIX;
extern const string _GSETTINGS_DIR;
extern const string _SOURCE_ROOT_DIR;
extern const string GETTEXT_PACKAGE;

public class GearyApplication : Gtk.Application {
    public const string NAME = _("Mail");
    public const string PRGNAME = "pantheon-mail";
    public const string APP_ID = "org.pantheon.mail";
    public const string COPYRIGHT = _("2011-2015 Yorba Foundation\n© 2016-2017 elementary LLC.");
    public const string WEBSITE = "https://elementary.io";
    public const string WEBSITE_LABEL = _("Website");
    public const string BUGREPORT = "https://github.com/elementary/mail/issues";
    public const string HELP = "https://elementary.io/help/geary";
    public const string TRANSLATE = "https://l10n.elementary.io/projects/mail";

    public const string CONTRACT_NAME = _("Send by Email");
    public const string CONTRACT_DESCRIPTION = _("Send files using Mail");

    public const string VERSION = _VERSION;
    public const string INSTALL_PREFIX = _INSTALL_PREFIX;
    public const string GSETTINGS_DIR = _GSETTINGS_DIR;
    public const string SOURCE_ROOT_DIR = _SOURCE_ROOT_DIR;
    public const string GRESOURCE_UI_PREFIX = "/io/elementary/pantheon-mail/ui";

    public const string[] AUTHORS = {
        "Jim Nelson <jim@yorba.org>",
        "Eric Gregory <eric@yorba.org>",
        "Nate Lillich <nate@yorba.org>",
        "Matthew Pirocchi <matthew@yorba.org>",
        "Charles Lindsay <chaz@yorba.org>",
        "Robert Schroll <rschroll@gmail.com>",
        null
    };

    public const string[] ARTISTS = {
        "Daniel Foré <daniel@elementary.io>",
        "Sam Hewitt <sam@elementary.io>",
        null
    };

    private const string ACTION_ENTRY_COMPOSE = "compose";

    public const ActionEntry[] action_entries = {
        {ACTION_ENTRY_COMPOSE, activate_compose, "s"},
    };

    private const int64 USEC_PER_SEC = 1000000;
    private const int64 FORCE_SHUTDOWN_USEC = 5 * USEC_PER_SEC;

    public static GearyApplication instance {
        get { return _instance; }
        private set {
            // Ensure singleton behavior.
            assert (_instance == null);
            _instance = value;
        }
    }

    /**
     * Signal that is activated when 'exit' is called, but before the application actually exits.
     *
     * To cancel an exit, a callback should return GearyApplication.cancel_exit(). To procede with
     * an exit, a callback should return true.
     */
    public virtual signal bool exiting(bool panicked) {
        return true;
    }

    public GearyController controller { get; private set; default = new GearyController(); }

    public Gtk.ActionGroup actions {
        get; private set; default = new Gtk.ActionGroup("GearyActionGroup");
    }
    public Gee.Collection<Geary.ActionAdapter> action_adapters {
        get; private set; default = new Gee.ArrayList<Geary.ActionAdapter>();
    }

    public Gtk.UIManager ui_manager {
        get; private set; default = new Gtk.UIManager();
    }

    public Configuration config { get; private set; }

    private static GearyApplication _instance = null;

    private string bin;
    private File exec_dir;
    private bool exiting_fired = false;
    private int exitcode = 0;
    private bool is_destroyed = false;

    public GearyApplication() {
        Object(application_id: APP_ID);

        _instance = this;
    }

    // Application.run() calls this as an entry point.
    public override bool local_command_line(ref unowned string[] args, out int exit_status) {
        bin = args[0];
        exec_dir = (File.new_for_path(Posix.realpath(Environment.find_program_in_path(bin)))).get_parent();

        try {
            register();
        } catch (Error e) {
            error("Error registering GearyApplication: %s", e.message);
        }

        startup();

        if (!Args.parse(args)) {
            exit_status = 1;
            return true;
        }

        activate();
        foreach (unowned string arg in args) {
            if (arg != null && arg.has_prefix(Geary.ComposedEmail.MAILTO_SCHEME))
                activate_action(ACTION_ENTRY_COMPOSE, new Variant.string(arg));
        }

        exit_status = 0;
        return true;
    }

    public override void startup() {
        Configuration.init(is_installed(), GSETTINGS_DIR);

        Environment.set_prgname(PRGNAME);
        International.init(GETTEXT_PACKAGE, bin);

        Geary.Logging.init();
        Date.init();
        WebKit.set_cache_model(WebKit.CacheModel.DOCUMENT_BROWSER);

        base.startup();

        var notification_action = new SimpleAction ("go-to-notification", null);
        notification_action.activate.connect (() => {
            this.activate ();
            controller.notification_clicked ();
        });
        add_action (notification_action);

        add_action_entries(action_entries, this);
    }

    public override void activate() {
        base.activate();

        if (!present())
            create_async.begin();
    }

    public void activate_compose(SimpleAction action, Variant? param) {
        if (param == null)
            return;

        compose(param.get_string());
    }

    public bool present() {
        if (controller == null)
            return false;

        // if LoginDialog (i.e. the opening dialog for creating the initial account) is present
        // and visible, bring that to top (to prevent opening the hidden main window, which is
        // empty)
        if (controller.login_dialog != null && controller.login_dialog.visible) {
            controller.login_dialog.present_with_time(Gdk.CURRENT_TIME);

            return true;
        }

        if (controller.main_window == null)
            return false;

        if (!controller.main_window.get_realized())
            controller.main_window.show_all();
        else
            controller.main_window.present_with_time(Gdk.CURRENT_TIME);

        return true;
    }

    private async void create_async() {
        // Manually keep the main loop around for the duration of this call.
        // Without this, the main loop will exit as soon as we hit the yield
        // below, before we create the main window.
        hold();

        // do *after* parsing args, as they dicate where logging is sent to, if anywhere, and only
        // after activate (which means this is only logged for the one user-visible instance, not
        // the other instances called when sending commands to the app via the command-line)
        message("%s %s prefix=%s exec_dir=%s is_installed=%s", NAME, VERSION, INSTALL_PREFIX,
            exec_dir.get_path(), is_installed().to_string());

        config = new Configuration(APP_ID);
        yield controller.open_async();

        release();
    }

    private async void destroy_async() {
        // see create_async() for reasoning hold/release is used
        hold();

        yield controller.close_async();

        release();

        is_destroyed = true;
    }

    public bool compose(string mailto) {
        if (controller == null)
            return false;

        controller.compose_mailto(mailto);
        return true;
    }

    // NOTE: This assert()'s if the Gtk.Action is not present in the default action group
    public Gtk.Action get_action(string name) {
        Gtk.Action? action = actions.get_action(name);
        assert(action != null);

        return action;
    }

    public File get_user_data_directory() {
        return File.new_for_path(Environment.get_user_data_dir()).get_child("pantheon-mail");
    }

    public File get_user_config_directory() {
        return File.new_for_path(Environment.get_user_config_dir()).get_child("pantheon-mail");
    }

    /**
     * Returns the base directory that the application's various resource files are stored.  If the
     * application is running from its installed directory, this will point to
     * $(BASEDIR)/share/<program name>.  If it's running from the build directory, this points to
     * that.
     */
    public File get_resource_directory() {
        if (get_install_dir() != null)
            return get_install_dir().get_child("share").get_child("pantheon-mail");
        else
            return File.new_for_path(SOURCE_ROOT_DIR + "/data");
    }

    // Returns the directory the application is currently executing from.
    public File get_exec_dir() {
        return exec_dir;
    }

    public File? get_desktop_file() {
        File? install_dir = get_install_dir();
        File desktop_file = (install_dir != null)
            ? install_dir.get_child("share").get_child("applications").get_child("pantheon-mail.desktop")
            : File.new_for_path(SOURCE_ROOT_DIR).get_child("build").get_child("desktop").get_child("pantheon-mail.desktop");

        return desktop_file.query_exists() ? desktop_file : null;
    }

    public bool is_installed() {
        return exec_dir.has_prefix(get_install_prefix_dir());
    }

    // Returns the configure installation prefix directory, which does not imply Geary is installed
    // or that it's running from this directory.
    public File get_install_prefix_dir() {
        return File.new_for_path(INSTALL_PREFIX);
    }

    // Returns the installation directory, or null if we're running outside of the installation
    // directory.
    public File? get_install_dir() {
        File prefix_dir = get_install_prefix_dir();

        return exec_dir.has_prefix(prefix_dir) ? prefix_dir : null;
    }

    // This call will fire "exiting" only if it's not already been fired.
    public void exit(int exitcode = 0) {
        if (exiting_fired)
            return;

        this.exitcode = exitcode;

        exiting_fired = true;
        if (!exiting(false)) {
            exiting_fired = false;
            this.exitcode = 0;

            return;
        }

        // Give asynchronous destroy_async() a chance to complete, but to avoid bug(s) where
        // Mail hangs at exit, shut the whole thing down if destroy_async() takes too long to
        // complete
        int64 start_usec = get_monotonic_time();
        destroy_async.begin();
        while (!is_destroyed || Gtk.events_pending()) {
            Gtk.main_iteration();

            int64 delta_usec = get_monotonic_time() - start_usec;
            if (delta_usec >= FORCE_SHUTDOWN_USEC) {
                debug("Forcing shutdown of Mail, %ss passed...", (delta_usec / USEC_PER_SEC).to_string());

                break;
            }
        }

        if (Gtk.main_level() > 0)
            Gtk.main_quit();
        else
            Posix.exit(exitcode);

        Date.terminate();
    }

    /**
     * A callback for GearyApplication.exiting should return cancel_exit() to prevent the
     * application from exiting.
     */
    public bool cancel_exit() {
        Signal.stop_emission_by_name(this, "exiting");
        return false;
    }

    // This call will fire "exiting" only if it's not already been fired and halt the application
    // in its tracks.
    public void panic() {
        if (!exiting_fired) {
            exiting_fired = true;
            exiting(true);
        }

        Posix.exit(1);
    }
}
