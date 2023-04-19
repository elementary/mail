vala_files = files(
    'Application.vala',
    'Composer.vala',
    'MainWindow.vala',
    'InboxMonitor.vala',
    'Utils.vala',
    'WebView.vala',
    'WelcomeView.vala',
    'Backend/Account.vala',
    'Backend/ContactManager.vala',
    'Backend/Session.vala',
    'Backend/MoveHandler.vala',
    'ConversationList/ConversationItemModel.vala',
    'ConversationList/ConversationList.vala',
    'ConversationList/ConversationListItem.vala',
    'ConversationList/ConversationListStore.vala',
    'Dialogs/InsertLinkDialog.vala',
    'FolderList/FolderList.vala',
    'FolderList/FolderListItem.vala',
    'FolderList/AccountItemModel.vala',
    'FolderList/FolderItemModel.vala',
    'FolderList/SessionItemModel.vala',
    'FolderList/GroupedFolderItemModel.vala',
    'MessageList/AttachmentButton.vala',
    'MessageList/MessageList.vala',
    'MessageList/MessageListItem.vala'
)

executable(
    meson.project_name(),
    vala_files,
    config_file,
    asresources,
    dependencies: dependencies,
    c_args: '-DWEBKIT_EXTENSION_PATH="' + webkit2_extension_path + '"',
    install: true
)
