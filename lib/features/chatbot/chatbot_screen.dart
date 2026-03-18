import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/chat_service.dart';
import 'widgets/message_list.dart';
import 'widgets/input_field.dart';

/// AI Safety Chatbot screen powered by Google Gemini.
/// Accessed via the '/chatbot' route from the home screen.
class ChatbotFeatureScreen extends StatefulWidget {
  const ChatbotFeatureScreen({super.key});

  @override
  State<ChatbotFeatureScreen> createState() => _ChatbotFeatureScreenState();
}

class _ChatbotFeatureScreenState extends State<ChatbotFeatureScreen> {
  @override
  void dispose() {
    // Clear session when navigating away for privacy
    Provider.of<ChatService>(context, listen: false).clearSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Women Safety Assistant'),
        backgroundColor: const Color(0xFF101D68),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF101D68), Color(0xFF3950C6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Consumer<ChatService>(
            builder: (context, chatService, child) {
              return Column(
                children: [
                  Expanded(
                    child: MessageList(
                      messages: chatService.messages,
                      isLoading: chatService.isLoading,
                      errorMessage: chatService.errorMessage,
                    ),
                  ),
                  InputField(
                    onSend: (text) => chatService.sendMessage(text),
                    isLoading: chatService.isLoading,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
