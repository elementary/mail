# Mail
[![Translation status](https://l10n.elementary.io/widgets/mail/-/svg-badge.svg)](https://l10n.elementary.io/projects/mail/?utm_source=widget)

## Building, Testing, and Installation

You'll need the following dependencies:
* cmake
* [cmake-elementary](https://code.launchpad.net/~elementary-os/+junk/cmake-modules)
* intltool
* libappstream-dev (>= 0.10)
* libgee-0.8-dev
* libgranite-dev
* libgtk-3-dev
* libjson-glib-dev
* libpackagekit-glib2-dev
* libsoup2.4-dev
* libunity-dev
* libxml2-dev
* libxml2-utils
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

