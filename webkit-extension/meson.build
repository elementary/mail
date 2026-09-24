extension_files = files(
    'Main.vala',
    'MailPage.vala',
)

shared_module('io.elementary.mail-webkit-extension',
    extension_files,
    dependencies: extension_dependencies,
    install: true,
    install_dir: webkit_extension_path
)

