vala_files = [
    'Application.vala',
    'MainWindow.vala',
    'HeaderBar.vala',
    'Utils.vala',
    'WebView.vala',
    'Backend/Account.vala',
    'Backend/ContactManager.vala',
    'Backend/Session.vala',
    'Composer/ComposerWidget.vala',
    'Composer/ComposerWidget.vala',
    'Composer/ComposerWindow.vala',
    'Composer/InlineComposer.vala',
    'ConversationList/ConversationItemModel.vala',
    'ConversationList/ConversationListBox.vala',
    'ConversationList/ConversationListItem.vala',
    'ConversationList/ConversationListStore.vala',
    'Dialogs/OpenAttachmentDialog.vala',
    'FoldersView/AccountSavedState.vala',
    'FoldersView/AccountSourceItem.vala',
    'FoldersView/FoldersListView.vala',
    'FoldersView/FolderSourceItem.vala',
    'MessageList/AttachmentBar.vala',
    'MessageList/AttachmentButton.vala',
    'MessageList/MessageListBox.vala',
    'MessageList/MessageListItem.vala',
    'VirtualizingListBox/VirtualizingListBoxModel.vala',
    'VirtualizingListBox/VirtualizingListBoxRow.vala',
    'VirtualizingListBox/VirtualizingListBox.vala'
]

executable(
    meson.project_name(),
    vala_files,
    asresources,
    dependencies: dependencies,
    c_args: '-DWEBKIT_EXTENSION_PATH="' + webkit2_extension_path + '"',
    install: true
)
