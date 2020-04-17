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
 * Authored by: David Hewitt <davidmhewitt@gmail.com>
 */

namespace WebkitWebExtension {
    private static void on_page_created (WebKit.WebPage page) {
        var mail_page = new Mail.Page (page);
        // Make so that the Mail.Page is destroyed at the same time of the WebKit.WebPage
        page.set_data ("elementary-mail-page", (owned) mail_page);
    }

    [CCode (cname = "G_MODULE_EXPORT webkit_web_extension_initialize", instance_pos = -1)]
    public void initialize (WebKit.WebExtension extension) {
        extension.page_created.connect (on_page_created);
    }
}
