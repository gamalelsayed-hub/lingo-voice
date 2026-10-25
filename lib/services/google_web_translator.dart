import 'dart:convert';

import 'package:http/http.dart' as http;

/// Free online translation through the endpoint Google Translate's web
/// widgets use. No key or account, and much better than the on-device model
/// with colloquial Arabic, but it is unofficial: Google can rate-limit or
/// change it, so callers must fall back to on-device translation.
class GoogleWebTranslator {
  GoogleWebTranslator({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    final uri = Uri.https('translate.googleapis.com', '/translate_a/single', {
      'client': 'gtx',
      'sl': from,
      'tl': to,
      'dt': 't',
      'q': text,
    });
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Google Translate ${response.statusCode}');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final parts = (body as List).first as List;
    final translated = parts
        .map((part) => (part as List).first as String)
        .join()
        .trim();
    if (translated.isEmpty) {
      throw Exception('Google Translate returned nothing');
    }
    return translated;
  }
}
