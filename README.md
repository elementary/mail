# Mail
[![Translation status](https://l10n.elementary.io/widgets/mail/-/svg-badge.svg)](https://l10n.elementary.io/projects/mail/?utm_source=widget)

## Building, Testing, and Installation

You'll need the following dependencies:
* cmake
* libaccounts-glib-dev
* libcanberra-dev
* libgcr-3-dev
* libgmime-2.6-dev
* libgranite-dev
* libgsignon-glib-dev
* libgtk-3-dev
* libsecret-1-dev
* libsqlite3-dev
* libxml2-dev
* valac (>= 0.26)

It's recommended to create a clean build environment

    mkdir build
    cd build/
    
Run `cmake` to configure the build environment and then `make` to build

    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make
    
To install, use `make install`, then execute with `pantheon-mail`

    sudo make install
    pantheon-mail

