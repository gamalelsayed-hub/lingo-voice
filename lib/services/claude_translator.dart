import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/levels.dart';

/// Translates the learner's (often Egyptian colloquial) Arabic into English
/// at their level with the Claude API. Much better than the on-device model
/// with dialect and half-finished sentences, but needs internet and an API
/// key from console.anthropic.com.
class ClaudeTranslator {
  ClaudeTranslator(this.apiKey, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static final _url = Uri.parse('https://api.anthropic.com/v1/messages');

  Future<String> toEnglish(String arabic, CefrLevel level) async {
    final response = await _client
        .post(
          _url,
          headers: {
            'content-type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2026-10-21',
            'anthropic-beta': 'server-side-fallback-2026-07-01',
          },
          body: jsonEncode({
            'model': 'claude-opus-5-5',
            'max_tokens': 1024,
            'fallbacks': 'default',
            'output_config': {'effort': 'low'},
            'system': _systemPrompt(level),
            'messages': [
              {'role': 'user', 'content': arabic},
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      final error = body is Map ? body['error'] : null;
      final message = error is Map ? error['message'] : null;
      throw Exception('Claude API ${response.statusCode}: ${message ?? ''}');
    }
    if (body['stop_reason'] == 'refusal') {
      throw Exception('Claude declined to translate this sentence');
    }
    final text = (body['content'] as List)
        .where((block) => block['type'] == 'text')
        .map((block) => block['text'] as String)
        .join()
        .trim();
    if (text.isEmpty) throw Exception('Claude returned no translation');
    return text;
  }

  static String _systemPrompt(CefrLevel level) =>
      'You help an Arabic speaker learn English. Each message is something '
      'they said aloud, often in Egyptian colloquial Arabic, as transcribed by '
      'phone speech recognition. It may be an unfinished sentence or contain '
      'recognition mistakes, so translate the most likely intended meaning. '
      'Write natural, everyday spoken English that a CEFR ${level.code} '
      'learner can understand: keep vocabulary and sentence length suitable '
      'for that level. Reply with the English translation only, with no '
      'notes, quotes or alternatives. Latency-sensitive; begin your visible '
      'answer immediately.';
}
