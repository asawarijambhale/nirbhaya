import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> messages = [];
  bool isLoading = false;

  //  OpenAI API Key
  final String apiKey = "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";

  Future<String> getAIResponse(String message) async {
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey"
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",
        "messages": [
          {
            "role": "system",
            "content": """
You are an AI assistant inside a Women Safety App.
Your role:
- Provide safety advice
- Give emotional support
- Suggest emergency actions
- Keep answers short and clear
- Be calm and supportive
"""
          },
          {"role": "user", "content": message}
        ],
        "temperature": 0.7
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["choices"][0]["message"]["content"];
    } else {
      return "Sorry, something went wrong. Please try again.";
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    String userMessage = _controller.text.trim();

    setState(() {
      messages.add({'sender': 'user', 'text': userMessage});
      _controller.clear();
      isLoading = true;
    });

    String botReply = await getAIResponse(userMessage);

    setState(() {
      messages.add({'sender': 'bot', 'text': botReply});
      isLoading = false;
    });

    Future.delayed(
      const Duration(milliseconds: 100),
      () => _scrollController.jumpTo(_scrollController.position.maxScrollExtent),
    );
  }

  Widget buildMessage(Map<String, String> message) {
    bool isUser = message['sender'] == 'user';

    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2E3BBE) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                Radius.circular(isUser ? 16 : 0),
            bottomRight:
                Radius.circular(isUser ? 0 : 16),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Text(
          message['text']!,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Women Safety Assistant"),
        backgroundColor: const Color(0xFF101D68),
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
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return buildMessage(messages[index]);
                },
              ),
            ),

            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),

            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(20)),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 0, horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF3950C6),
                            Color(0xFF101D68)
                          ],
                        ),
                      ),
                      child: const Icon(Icons.send,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}