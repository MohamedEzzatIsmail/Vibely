// lib/layout/chats/chat_screen_hooks.dart
//
// Mixin to be used by ChatScreen's State.
// Registers the current chatId with FCMService so in-app notification
// banners are suppressed while the conversation is open.
//
// Usage in ChatScreen State:
//   with ChatScreenHooks
//   then call hookFCM(chatId) in initState and unhookFCM() in dispose.

import '../notifications/fcm_service.dart';

mixin ChatScreenHooks {
  void hookFCM(String chatId) => FCMService.setActiveChatId(chatId);
  void unhookFCM()            => FCMService.setActiveChatId(null);
}
