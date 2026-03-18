import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:http/http.dart' as http;

abstract class GeminiClient {
  Future<String> generateResponse(String userQuery);
}

class GeminiClientImpl implements GeminiClient {
  final String apiKey;
  final http.Client httpClient;
  final String baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  static const String systemPrompt = '''
You are a women\'s safety assistant. ONLY provide safety advice when the user asks a genuine safety-related question.

CONTEXT AWARENESS:
- If the user asks about homework, greetings, or non-safety topics: Politely redirect them
- If the user admits to harassing or harming others: Firmly but respectfully tell them that\'s wrong
- If the user asks a genuine safety question: Provide brief, actionable advice

RESPONSE FORMAT (for safety questions only):
- Maximum 5-7 bullet points
- Each point: ONE short sentence with a clear action
- Use **bold** for key action words (e.g., **Call 112**, **Move to**, **Stay in**)
- No introductions, no explanations
- Direct, immediate actions only

Be supportive, context-aware, and appropriate.
''';

  GeminiClientImpl({required this.apiKey, http.Client? httpClient})
      : httpClient = httpClient ?? http.Client();

  @override
  Future<String> generateResponse(String userQuery) async {
    if (apiKey.isEmpty) {
      throw ConfigurationException(
          'API key is not configured. Please set the GEMINI_API_KEY environment variable.');
    }

    final url = Uri.parse('$baseUrl/models/gemini-2.5-flash:generateContent');
    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': '$systemPrompt\n\nUser: $userQuery'}
          ]
        }
      ]
    };

    try {
      final response = await httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        _handleHttpError(response.statusCode, response.body);
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final text = responseData['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null) {
        throw ApiException('Response error: Received an unexpected response. Please try again.');
      }
      return text;
    } on SocketException {
      throw ApiException('Connection error: Please check your internet connection and try again.');
    } on TimeoutException {
      throw ApiException('Connection error: Please check your internet connection and try again.');
    } on ApiException {
      rethrow;
    } on ConfigurationException {
      rethrow;
    } catch (_) {
      throw ApiException('Request error: Unable to process your message. Please try again.');
    }
  }

  void _handleHttpError(int statusCode, String responseBody) {
    switch (statusCode) {
      case 401:
      case 403:
        throw ApiException(
            'Authentication error: Your API key is invalid or expired.',
            statusCode: statusCode);
      case 429:
        throw ApiException(
            'Too many requests. Please wait a moment and try again.',
            statusCode: statusCode);
      default:
        throw ApiException('Request error: Unable to process your message. Please try again.',
            statusCode: statusCode);
    }
  }
}

class ConfigurationException implements Exception {
  final String message;
  ConfigurationException(this.message);
  @override
  String toString() => 'ConfigurationException: $message';
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException: $message';
}
