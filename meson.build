project('io.elementary.mail', 'vala', 'c')

gnome = import('gnome')
i18n = import('i18n')

glib_dep = dependency('glib-2.0')
gobject_dep = dependency('gobject-2.0')
granite_dep = dependency('granite')
gee_dep = dependency('gee-0.8')
camel_dep = dependency('camel-1.2')
libedataserver_dep = dependency('libedataserver-1.2', version: '>= 3.25.2')
libedataserverui_dep = dependency('libedataserverui-1.2')
webkit2_dep = dependency('webkit2gtk-4.0')
webkit2_web_extension_dep = dependency('webkit2gtk-web-extension-4.0')
folks_dep = dependency('folks')
m_dep = meson.get_compiler('c').find_library('m')

webkit2_extension_path = join_paths(get_option('prefix'), get_option('libdir'), meson.project_name(), 'webkit2')

dependencies = [
    glib_dep,
    gobject_dep,
    granite_dep,
    gee_dep,
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

add_global_arguments('-DGETTEXT_PACKAGE="' + meson.project_name() + '"', language:'c')

meson.add_install_script('meson/post_install.py')

subdir('src')
subdir('webkit-extension')
subdir('data')
subdir('po')
