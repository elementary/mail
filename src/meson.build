vala_files = [
    'Application.vala',
    'MainWindow.vala',
    'HeaderBar.vala',
    'WebView.vala',
    'WebViewServer.vala',
    'Backend/Session.vala',
    'Backend/Account.vala',
    'FoldersView/AccountSourceItem.vala',
    'FoldersView/FoldersListView.vala',
    'FoldersView/FolderSourceItem.vala',
    'ConversationList/ConversationListBox.vala',
    'ConversationList/ConversationListItem.vala',
    'MessageList/MessageListBox.vala',
    'MessageList/MessageListItem.vala'
]

executable('io.elementary.mail',
    vala_files,
    asresources,
    dependencies: dependencies,
    c_args: '-DWEBKIT_EXTENSION_PATH="' + webkit2_extension_path + '"',
    install: true
)
