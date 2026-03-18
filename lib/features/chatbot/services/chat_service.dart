import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import 'gemini_client.dart';

abstract class ChatService extends ChangeNotifier {
  List<ChatMessage> get messages;
  bool get isLoading;
  String? get errorMessage;
  Future<void> sendMessage(String userInput);
  void clearError();
  void clearSession();
}

class ChatServiceImpl extends ChatService {
  final GeminiClient _geminiClient;
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;

  ChatServiceImpl({required GeminiClient geminiClient})
      : _geminiClient = geminiClient;

  @override
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  @override
  Future<void> sendMessage(String userInput) async {
    _messages.add(ChatMessage(
      text: userInput,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    ));
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final responseText = await _geminiClient.generateResponse(userInput);
      _messages.add(ChatMessage(
        text: responseText,
        sender: MessageSender.bot,
        timestamp: DateTime.now(),
      ));
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      if (e is ApiException) {
        _errorMessage = e.message;
      } else if (e is ConfigurationException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      }
      notifyListeners();
    }
  }

  @override
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void clearSession() {
    _messages.clear();
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
