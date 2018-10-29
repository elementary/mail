vala_files = files(
    'Application.vala',
    'MainWindow.vala',
    'HeaderBar.vala',
    'Dialogs/OpenAttachmentDialog.vala',
    'Utils.vala',
    'WebView.vala',
    'WelcomeView.vala',
    'Backend/Session.vala',
    'Backend/Account.vala',
    'Backend/ContactManager.vala',
    'Composer/ComposerWidget.vala',
    'Composer/ComposerWindow.vala',
    'Composer/InlineComposer.vala',
    'FoldersView/AccountSavedState.vala',
    'FoldersView/AccountSourceItem.vala',
    'FoldersView/FoldersListView.vala',
    'FoldersView/FolderSourceItem.vala',
    'ConversationList/ConversationListBox.vala',
    'ConversationList/ConversationListItem.vala',
    'MessageList/MessageListBox.vala',
    'MessageList/MessageListItem.vala',
    'MessageList/AttachmentBar.vala',
    'MessageList/AttachmentButton.vala'
)

executable(
    meson.project_name(),
    vala_files,
    asresources,
    dependencies: dependencies,
    c_args: '-DWEBKIT_EXTENSION_PATH="' + webkit2_extension_path + '"',
    install: true
)
