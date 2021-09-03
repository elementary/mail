daemon_files = files(
    'Daemon.vala'
)

daemon_deps = [
    glib_dep,
    gobject_dep,
    granite_dep,
    camel_dep,
    libedataserver_dep
]

executable(
    meson.project_name()+'-daemon',
    daemon_files,
    dependencies: daemon_deps,
    install: true,
    install_dir: join_paths(get_option('prefix'), get_option('libexecdir'))
)