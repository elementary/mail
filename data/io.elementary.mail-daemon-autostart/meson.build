daemon_autostart_desktop_config = configuration_data()
daemon_autostart_desktop_config.set('EXEC_PATH', libexecdir+'-daemon')
configure_file (
    input: meson.project_name()+'-daemon-autostart' + '.desktop.in',
    output: meson.project_name()+'-daemon' + '.desktop',
    configuration: daemon_autostart_desktop_config,
    install_dir: join_paths(get_option('sysconfdir'), 'xdg', 'autostart')
)
