// Thin wrapper that preserves the existing ChatbotScreen class name
// so all routes and imports in main.dart remain unchanged.
import '../features/chatbot/chatbot_screen.dart';

export '../features/chatbot/chatbot_screen.dart' show ChatbotFeatureScreen;

// ChatbotScreen is now ChatbotFeatureScreen — re-export with original name.
typedef ChatbotScreen = ChatbotFeatureScreen;
