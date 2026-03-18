import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import 'message_bubble.dart';

class MessageList extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;

  const MessageList({
    super.key,
    required this.messages,
    required this.isLoading,
    this.errorMessage,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  int get _itemCount {
    if (widget.messages.isEmpty && !widget.isLoading && widget.errorMessage == null) return 1;
    int count = widget.messages.length;
    if (widget.errorMessage != null) count++;
    if (widget.isLoading) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: _itemCount,
      itemBuilder: (context, index) {
        if (widget.messages.isEmpty && !widget.isLoading && widget.errorMessage == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64.0, color: Colors.grey[400]),
                  const SizedBox(height: 16.0),
                  Text('Start a conversation',
                      style: TextStyle(fontSize: 18.0, color: Colors.grey[600])),
                  const SizedBox(height: 8.0),
                  Text('Ask me anything about safety',
                      style: TextStyle(fontSize: 14.0, color: Colors.grey[500])),
                ],
              ),
            ),
          );
        }

        if (index < widget.messages.length) {
          return MessageBubble(message: widget.messages[index]);
        }

        if (widget.errorMessage != null && index == widget.messages.length) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.red[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20.0),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(widget.errorMessage!,
                      style: TextStyle(color: Colors.red[900], fontSize: 14.0)),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              SizedBox(
                width: 20.0,
                height: 20.0,
                child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!)),
              ),
              const SizedBox(width: 12.0),
              Text('Thinking...',
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 14.0, fontStyle: FontStyle.italic)),
            ],
          ),
        );
      },
    );
  }
}
