/// Represents the origin of a chat message
enum MessageSender {
  /// Message sent by the user
  user,

  /// Message sent by the AI chatbot
  bot,
}

/// Represents a single message in the chat conversation
class ChatMessage {
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
  }) {
    if (text.isEmpty) {
      throw ArgumentError('Message text cannot be empty');
    }
    if (timestamp.isAfter(DateTime.now())) {
      throw ArgumentError('Message timestamp cannot be in the future');
    }
  }
}
