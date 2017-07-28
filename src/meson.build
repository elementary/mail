vala_files = [
    'Application.vala',
    'MainWindow.vala',
    'HeaderBar.vala',
    'Dialogs/OpenAttachmentDialog.vala',
    'WebView.vala',
    'WebViewServer.vala',
    'Backend/Session.vala',
    'Backend/Account.vala',
    'Composer/ComposerActions.vala',
    'Composer/ComposerWindow.vala',
    'Composer/ComposerWidget.vala',
    'Composer/InlineComposer.vala',
    'FoldersView/AccountSourceItem.vala',
    'FoldersView/FoldersListView.vala',
    'FoldersView/FolderSourceItem.vala',
    'ConversationList/ConversationListBox.vala',
    'ConversationList/ConversationListItem.vala',
    'MessageList/MessageListBox.vala',
    'MessageList/MessageListItem.vala',
    'MessageList/AttachmentBar.vala',
    'MessageList/AttachmentButton.vala'
]

executable('io.elementary.mail',
    vala_files,
    asresources,
    dependencies: dependencies,
    c_args: '-DWEBKIT_EXTENSION_PATH="' + webkit2_extension_path + '"',
    link_args : '-lm',
    install: true
)
