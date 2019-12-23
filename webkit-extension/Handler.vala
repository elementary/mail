/*-
 * Copyright 2019 elementary, Inc. (https://elementary.io)
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

public class Mail.WebExtensionHandler : Object {
    construct {
        critical ("HERE");
    }

    ~WebExtensionHandler () {
        critical ("Free");
    }

    [CCode (instance_pos = 2.9)]
    public bool class_delete_property_function (JSC.Class jsc_class, JSC.Context context, string name) {
        critical ("delete property");
        return false;
    }

    [CCode (array_length = false, array_null_terminated = true, instance_pos = 2.9)]
    public string[]? class_enumerate_properties_function (JSC.Class jsc_class, JSC.Context context) {
        critical ("enumerate property");
        return null;
    }

    [CCode (instance_pos = 2.9)]
    public JSC.Value? class_get_property_function (JSC.Class jsc_class, JSC.Context context, string name) {
        critical ("get property");
        return null;
    }

    [CCode (instance_pos = 2.9)]
    public bool class_has_property_function (JSC.Class jsc_class, JSC.Context context, string name) {
        critical ("has property");
        return false;
    }

    [CCode (instance_pos = 2.9)]
    public bool class_set_property_function (JSC.Class jsc_class, JSC.Context context, string name, JSC.Value value) {
        critical ("set property");
        return false;
    }

    public int get_height () {
        critical ("getheight");
        return 500;
    }
}
