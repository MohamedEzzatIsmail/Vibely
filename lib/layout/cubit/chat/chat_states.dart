// lib/layout/cubit/chat/chat_states.dart
// All states including new ones from prompts 26

abstract class ChatStates {}

class ChatInitialState              extends ChatStates {}
class ChatMessagesUpdatedState      extends ChatStates {}
class ChatSendMessageSuccessState   extends ChatStates {}
class ChatSendingMediaState         extends ChatStates {
  final double? progress; // 0.0–1.0, null = indeterminate
  ChatSendingMediaState({this.progress});
}
class ChatTypingUpdatedState        extends ChatStates {}
class ChatUsersLoadedState          extends ChatStates {}
class ChatUnreadUpdatedState        extends ChatStates {}
class ChatOnlineUpdatedState        extends ChatStates {}
class ChatMessageDeletedState       extends ChatStates {}
class ChatMessageEditedState        extends ChatStates {}
class ChatReactionToggledState      extends ChatStates {}
class ChatGroupCreatedState         extends ChatStates {}
class ChatGroupLoadedState          extends ChatStates {}
class ChatGroupUpdatedState         extends ChatStates {}     // name/photo changed
class ChatGroupMemberAddedState     extends ChatStates {}     // member added
class ChatGroupMemberRemovedState   extends ChatStates {}     // member removed
class ChatGroupDeletedState         extends ChatStates {}     // deleted by admin
class ChatGroupLeftState            extends ChatStates {}     // current user left
class ChatConversationMutedState    extends ChatStates {}
class ChatConversationPinnedState   extends ChatStates {}
class ChatConversationDeletedState  extends ChatStates {}
class ChatArchivedState             extends ChatStates {}     // archived/unarchived
class ChatUserBlockedState          extends ChatStates {}
class ChatUserReportedState         extends ChatStates {}
class ChatDisappearingMsgState      extends ChatStates {}     // timer changed
class ChatScrollToMessageState      extends ChatStates {      // scroll to quoted
  final String targetDocId;
  ChatScrollToMessageState(this.targetDocId);
}

class ChatErrorState extends ChatStates {
  final String message;
  ChatErrorState(this.message);
}
