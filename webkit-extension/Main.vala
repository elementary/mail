/*-
 * Copyright 2017-2019 elementary, Inc. (https://elementary.io)
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
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 *              Corentin Noël <corentin@elementary.io>
 */

public class Mail.WebExtension : Object {
    static Mail.WebExtension instance;
    [CCode (cname = "G_MODULE_EXPORT webkit_web_extension_initialize")]
    public static void initialize (WebKit.WebExtension extension) {
        instance = new WebExtension (extension);
    }

    public WebKit.WebExtension extension { get; construct; }
    public WebExtension (WebKit.WebExtension extension) {
        Object (extension: extension);
    }

    construct {
        extension.page_created.connect (on_page_created);
    }

    [CCode (instance_pos = 1.9)]
    private Mail.WebExtensionHandler create_handler (GLib.GenericArray<JSC.Value> values) {
        return new Mail.WebExtensionHandler ();
    }

    [CCode (instance_pos = 2.9)]
    private int get_height (Mail.WebExtensionHandler handler, GLib.GenericArray<JSC.Value> values) {
        critical ("HERE");
        return handler.get_height ();
    }

    private void on_page_created (WebKit.WebPage web_page) {
        JSC.Context js_context = web_page.get_main_frame ().get_js_context ();
        js_context.push_exception_handler ((context, exception) => {
            critical ("%s", exception.report ());
        });
        const JSC.ClassVTable vtable = {
            (JSC.ClassGetPropertyFunction) Mail.WebExtensionHandler.class_get_property_function,
            (JSC.ClassSetPropertyFunction) Mail.WebExtensionHandler.class_set_property_function,
            (JSC.ClassHasPropertyFunction) Mail.WebExtensionHandler.class_has_property_function,
            (JSC.ClassDeletePropertyFunction) Mail.WebExtensionHandler.class_delete_property_function,
            (JSC.ClassEnumeratePropertiesFunction) Mail.WebExtensionHandler.class_enumerate_properties_function
        };
        unowned JSC.Class handler_class = js_context.register_class ("MailWebExtensionHandler", null, vtable, (GLib.DestroyNotify) GLib.Object.unref);
        var constructor = handler_class.add_constructor_variadic (null, (GLib.Callback) create_handler, this, null, typeof (Mail.WebExtensionHandler));
        js_context.set_value (handler_class.name, constructor);
        handler_class.add_method_variadic ("getHeight", (GLib.Callback) get_height, this, null, typeof(int));
        critical ("Page created");
    }
}
