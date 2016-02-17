#
# Build and install pantheon-mail.desktop
#

configure_file(pantheon-mail.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/pantheon-mail.desktop)
configure_file(pantheon-mail-autostart.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/pantheon-mail-autostart.desktop)

install(FILES pantheon-mail.appdata.xml DESTINATION share/appdata)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/pantheon-mail.desktop DESTINATION share/applications)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/pantheon-mail-autostart.desktop DESTINATION share/applications)

install(FILES mail-attach DESTINATION bin)
install(FILES mail-attach.contract DESTINATION share/contractor)

# Optional: run update-desktop-database at install time.
# (This has to happen after the pantheon-mail.desktop file is installed.)
if (DESKTOP_UPDATE)
    install(
        CODE
            "execute_process (COMMAND update-desktop-database)"
        CODE
            "message (STATUS \"Updating desktop database\")"
    )
    
    add_custom_target(
        uninstall-desktop-update
        COMMAND
            update-desktop-database
    )
    
    add_dependencies(post-uninstall uninstall-desktop-update)
else ()
    install(
        CODE "message (STATUS \"Not updating desktop database\")"
    )
endif ()

add_subdirectory(theming)
add_subdirectory(ui)
