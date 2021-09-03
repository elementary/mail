/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public class Mail.Daemon : GLib.Application {

    construct {
        warning ("Daemon::construct");
    }

    protected override void activate () {
        Gtk.main ();
    }
}

namespace Mail {
    private static bool has_debug;

    const OptionEntry[] OPTIONS = {
        { "debug", 'd', 0, OptionArg.NONE, out has_debug, N_("Print debug information"), null },
        { null }
    };

    public static int main (string[] args) {
        OptionContext context = new OptionContext ("");
        context.add_main_entries (OPTIONS, null);

        try {
            context.parse (ref args);
        } catch (OptionError e) {
            error (e.message);
        }

        Granite.Services.Logger.initialize ("Mail");
        Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.WARN;

        if (has_debug) {
            Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.DEBUG;
        }

        var app = new Daemon ();

        return app.run (args);
    }
}