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

public class GravatarIcon: Object, Icon, LoadableIcon {

    public string address { get; construct; }
    public int scale { get; construct; }

    public GravatarIcon (string address, int scale) {
        Object (address: address, scale: scale);
    }

    public bool equal (Icon? icon) {
        var gravatar_icon = (GravatarIcon?) icon;
        if (gravatar_icon == null) {
            return false;
        }
        return address == gravatar_icon.address && scale == gravatar_icon.scale;
    }

    public uint hash () {
        return "%s-@%i".printf (address, scale).hash ();
    }

    public InputStream load (int size, out string? type, Cancellable? cancellable = null) throws Error {
        var uri = "https://secure.gravatar.com/avatar/%s?d=404&s=%d".printf (
            Checksum.compute_for_string (ChecksumType.MD5, address.strip ().down ()),
            size * scale
        );
        type = null;
        var server_file = File.new_for_uri (uri);
        var path = Path.build_filename (Environment.get_tmp_dir (), server_file.get_basename ());
        var local_file = File.new_for_path (path);

        if (!local_file.query_exists (cancellable)) {
            server_file.copy (local_file, FileCopyFlags.OVERWRITE, cancellable, null);
        }
        return local_file.read ();
    }

    public async InputStream load_async (int size, Cancellable? cancellable = null, out string? type = null) throws Error {
        return load (size, out type, cancellable);
    }
}