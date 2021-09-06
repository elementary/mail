daemon_notification_desktop_config = configuration_data()
daemon_notification_desktop_config.set('EXEC_PATH', meson.project_name())
configure_file (
    input: meson.project_name()+'-daemon-notifications' + '.desktop.in',
    output: meson.project_name()+'-daemon' + '.desktop',
    configuration: daemon_notification_desktop_config,
    install_dir: join_paths(get_option('datadir'), 'applications')
)
