# Mail
[![Translation status](https://l10n.elementary.io/widgets/mail/-/svg-badge.svg)](https://l10n.elementary.io/projects/mail/?utm_source=widget)

## Building, Testing, and Installation

You'll need the following dependencies:
* libaccounts-glib-dev
* libcanberra-dev
* libgcr-3-dev
* libgirepository1.0-dev
* libglib2.0-dev
* libgmime-2.6-dev
* libgranite-dev
* libgsignon-glib-dev
* libgtk-3-dev
* libsecret-1-dev
* libsqlite3-dev
* libunity-dev
* libwebkitgtk-3.0-dev
* libxml2-dev
* valac (>= 0.26)

Run meson build to configure the build environment and then change to the build directory and run ninja to build

    meson build
    cd build
    mesonconf -Dprefix=/usr
    ninja

To install, use ninja install, then execute with io.elementary.mail

    sudo ninja install
    io.elementary.mail

