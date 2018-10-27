valadoc = find_program('valadoc')

basic_command = [
    valadoc,
    '--force',
    '--verbose',
    '--package-name',meson.project_name(),
    '--package-version', meson.project_version(),
    '--driver', meson.get_compiler('vala').version(),
    '--pkg', 'folks',
    '--pkg', 'webkit2gtk-4.0',
    '--pkg', 'libedataserverui-1.2',
    '--pkg', 'libedataserver-1.2',
    '--pkg', 'camel-1.2',
    '--pkg', 'gee-0.8', 
    '--pkg', 'granite',
    '--pkg', 'gobject-2.0',
    '--pkg', 'glib-2.0',
    '--importdir=' + join_paths(get_option('prefix'), get_option('datadir'), 'gtk-doc', 'html'),
    '--doclet=html',
    '--use-svg-images'
]

all_doc_target = custom_target(
    'full documentation',
    command: [
        basic_command,
        '--internal',
        '-o', '@OUTPUT@',
        '@INPUT@'
    ],
    build_by_default: true,
    input: vala_files,
    output: 'full'
)

