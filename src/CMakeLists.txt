vala_precompile(VALA_C ${EXEC_NAME}
    Application.vala
    MainWindow.vala
    HeaderBar.vala
    Backend/Session.vala
    Backend/Account.vala
    FoldersView/AccountSourceItem.vala
    FoldersView/FoldersListView.vala
    FoldersView/FolderSourceItem.vala
    ConversationList/ConversationListBox.vala
    ConversationList/ConversationListItem.vala
PACKAGES
    gtk+-3.0>=3.12
    gee-0.8
    granite
    camel-1.2
    libedataserver-1.2
    libedataserverui-1.2
    webkit2gtk-4.0
    ${UNITY_PACKAGES}
OPTIONS
  --vapidir=${CMAKE_SOURCE_DIR}/vapi
  --target-glib=2.32
  --thread
  ${UNITY_OPTIONS}
)

add_executable (${EXEC_NAME} ${VALA_C})
target_link_libraries (${EXEC_NAME} ${DEPS_LIBRARIES} ${UNITY_LIBRARIES})

install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)
