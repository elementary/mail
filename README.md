# Mail
[![Translation status](https://l10n.elementary.io/widgets/mail/-/svg-badge.svg)](https://l10n.elementary.io/projects/mail/?utm_source=widget)

![Mail Screenshot](data/screenshot.png?raw=true)

## Building, Testing, and Installation

You'll need the following dependencies:
* libcamel1.2-dev
* libedataserver1.2-dev
* libedataserverui1.2-dev
* libfolks-dev
* libgee-0.8-dev
* libglib2.0-dev
* libgranite-dev >= 6.0.0
* libhandy-1-dev >= 1.1.90
* libwebkit2gtk-4.0-dev
* valac

Run `meson build` to configure the build environment and then change to the build directory and run `ninja` to build

    meson build --prefix=/usr
    cd build
    ninja

To install, use `ninja install`, then execute with `io.elementary.mail`

    sudo ninja install
    io.elementary.mail

You might want to set the `WEBKIT_EXTENSION_PATH` environment variable to the `webkit-extension` build folder in order to test the application without installing it

## Connecting Your Account

Mail uses Evolution Data Server and Camel to display your emails. Currently, the easiset way to test Mail with your accounts is to set up them up in Evolution first. Ultimately, setting up an account in Online Accounts will connect it to EDS/Camel but that has not yet been implemented.
