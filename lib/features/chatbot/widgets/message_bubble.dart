import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    final timeFormat = DateFormat('HH:mm');

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF101D68) : Colors.grey[300],
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUser)
              Text(message.text,
                  style: const TextStyle(color: Colors.white, fontSize: 16.0))
            else
              MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.black87, fontSize: 16.0),
                  strong: const TextStyle(
                      color: Colors.black87, fontWeight: FontWeight.bold),
                  listBullet: const TextStyle(color: Colors.black87, fontSize: 16.0),
                ),
              ),
            const SizedBox(height: 4.0),
            Text(
              timeFormat.format(message.timestamp),
              style: TextStyle(
                  color: isUser ? Colors.white70 : Colors.black54, fontSize: 12.0),
            ),
          ],
        ),
      ),
    );
  }
}
