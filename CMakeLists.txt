project (io.elementary.mail C)

cmake_minimum_required (VERSION 2.8)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")
set (PKGDATADIR "${DATADIR}/${CMAKE_PROJECT_NAME}")
set (GETTEXT_PACKAGE ${CMAKE_PROJECT_NAME})
set (EXEC_NAME ${CMAKE_PROJECT_NAME})
set (VERSION "0.2.4")

# CTest
include (CTest)
if (BUILD_TESTING)
    add_test (NAME validate-desktop-file COMMAND desktop-file-validate ${CMAKE_BINARY_DIR}/data/io.elementary.appcenter.desktop)
    add_test (NAME validate-daemon-desktop-file COMMAND desktop-file-validate ${CMAKE_BINARY_DIR}/data/io.elementary.appcenter-daemon.desktop)
    add_test (NAME validate-appdata COMMAND appstreamcli validate ${CMAKE_BINARY_DIR}/data/appcenter.appdata.xml)
endif ()

add_definitions (-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
add_definitions (-w)

find_package (PkgConfig)
pkg_check_modules (DEPS REQUIRED
    gthread-2.0
    gee-0.8
    gtk+-3.0>=3.10
    granite
    camel-1.2
    libedataserver-1.2
    libedataserverui-1.2
    webkit2gtk-4.0)

add_definitions (${DEPS_CFLAGS})
link_directories (${DEPS_LIBRARY_DIRS})

pkg_check_modules (UNITY unity>=4.0.0)
if (UNITY_FOUND)
    set (UNITY_OPTIONS -D HAVE_UNITY)
    set (UNITY_PACKAGES unity)
    add_definitions(${UNITY_CFLAGS})
    link_directories(${UNITY_LIBRARY_DIRS})
endif ()

find_package (Vala REQUIRED)
include (ValaVersion)
ensure_vala_version ("0.26" MINIMUM)

include (ValaPrecompile)

add_subdirectory (data)
add_subdirectory (po)
add_subdirectory (src)
