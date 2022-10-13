import 'package:flutter_chat_ui/flutter_chat_ui.dart';

/// Base chat l10n containing all required variables to provide localized chatwoot chat
class ChatwootDefaultL10n extends ChatL10n {
  /// Placeholder for the text field
  final String onlineText;

  /// Placeholder for the text field
  final String offlineText;

  /// Placeholder for the text field
  final String typingText;

  /// Message when agent resolves conversation
  final String conversationResolvedMessage;

  /// Creates a new chatwoot l10n
  const ChatwootDefaultL10n(
      {String attachmentButtonAccessibilityLabel = "",
      String emptyChatPlaceholder = "",
      String fileButtonAccessibilityLabel = "",
      this.onlineText = "Typically replies in a few hours",
      this.offlineText = "We're away at the moment",
      this.typingText = "typing...",
      String unreadMessagesLabel = "Unread messages",
      String inputPlaceholder = "Type your message",
      String sendButtonAccessibilityLabel = "Send Message",
      this.conversationResolvedMessage =
          "Your ticket has been marked as resolved"})
      : super(
            unreadMessagesLabel: unreadMessagesLabel,
            attachmentButtonAccessibilityLabel:
                attachmentButtonAccessibilityLabel,
            emptyChatPlaceholder: emptyChatPlaceholder,
            fileButtonAccessibilityLabel: fileButtonAccessibilityLabel,
            inputPlaceholder: inputPlaceholder,
            sendButtonAccessibilityLabel: sendButtonAccessibilityLabel);
}
