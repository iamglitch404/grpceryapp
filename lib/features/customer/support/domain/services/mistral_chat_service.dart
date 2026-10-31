import 'dart:convert';
import 'package:app/core/network/http_client.dart' as http;
import 'package:app/core/config/app_config.dart';

class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class MistralChatService {
  Future<String> sendMessage(
    List<ChatMessage> history,
    String newMessage,
  ) async {
    final messages = [
      ...history,
      ChatMessage(role: 'user', content: newMessage),
    ];

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'messages': messages.map((m) => m.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'] as String;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(
          data['error'] ??
              'Failed to communicate with chat API: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
