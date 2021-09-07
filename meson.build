project(
    'io.elementary.mail',
    'vala', 'c',
    version: '6.1.1'
)

gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(['--vapidir', join_paths(meson.current_source_dir(), 'vapi')], language: 'vala')

libexecdir = join_paths (get_option('prefix'), get_option('libexecdir'), meson.project_name())

glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
granite_dep = dependency('granite', version: '>= 6.0.0')
gee_dep = dependency('gee-0.8')
handy_dep = dependency('libhandy-1', version: '>=1.1.90')
camel_dep = dependency('camel-1.2', version: '>= 3.28')
libedataserver_dep = dependency('libedataserver-1.2', version: '>= 3.28')
libedataserverui_dep = dependency('libedataserverui-1.2', version: '>= 3.28')
webkit2_dep = dependency('webkit2gtk-4.0', version: '>=2.28')
webkit2_web_extension_dep = dependency('webkit2gtk-web-extension-4.0', version: '>=2.28')
folks_dep = dependency('folks')
m_dep = meson.get_compiler('c').find_library('m')

webkit2_extension_path = join_paths(get_option('prefix'), get_option('libdir'), meson.project_name(), 'webkit2')

dependencies = [
    glib_dep,
    gobject_dep,
    granite_dep,
    gee_dep,
    handy_dep,
    camel_dep,
    libedataserver_dep,
    libedataserverui_dep,
    webkit2_dep,
    folks_dep,
    m_dep
]

asresources = gnome.compile_resources(
    'as-resources', 'data/' + meson.project_name() + '.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

extension_dependencies = [
    glib_dep,
    gobject_dep,
    gee_dep,
    webkit2_web_extension_dep
]

add_global_arguments([
        '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
        '-DHANDY_USE_UNSTABLE_API'
    ],
    language:'c'
)

meson.add_install_script('meson/post_install.py')

config_data = configuration_data()
config_data.set('GETTEXT_PACKAGE', meson.project_name())
config_data.set('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))

config_file = configure_file(
    input: 'Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

subdir('src')
subdir('webkit-extension')
subdir('data')
subdir('po')
if get_option('documentation')
    subdir('docs')
endif
