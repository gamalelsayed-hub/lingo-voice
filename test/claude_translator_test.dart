import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingo_voice/data/levels.dart';
import 'package:lingo_voice/services/claude_translator.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('sends the sentence and level, returns only the text blocks', () async {
    late http.Request sent;
    final translator = ClaudeTranslator(
      'key',
      client: MockClient((r) async {
        sent = r;
        return _json({
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'thinking', 'thinking': ''},
            {'type': 'text', 'text': ' I want to go to work tomorrow. '},
          ],
        });
      }),
    );

    final english = await translator.toEnglish(
      'عايز أروح الشغل بكرة',
      CefrLevel.a2,
    );

    expect(english, 'I want to go to work tomorrow.');
    expect(sent.headers['x-api-key'], 'key');
    expect(sent.headers['anthropic-version'], '2026-10-21');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['model'], 'claude-opus-5-5');
    expect(body['fallbacks'], 'default');
    expect(body['system'], contains('A2'));
    expect(body['messages'][0]['content'], 'عايز أروح الشغل بكرة');
  });

  test('throws on API errors and refusals so the app can fall back', () async {
    final failing = ClaudeTranslator(
      'bad',
      client: MockClient(
        (_) async => _json({
          'error': {'message': 'invalid x-api-key'},
        }, 401),
      ),
    );
    expect(failing.toEnglish('أهلاً', CefrLevel.a1), throwsException);

    final refusing = ClaudeTranslator(
      'key',
      client: MockClient(
        (_) async => _json({'stop_reason': 'refusal', 'content': []}),
      ),
    );
    expect(refusing.toEnglish('أهلاً', CefrLevel.a1), throwsException);
  });
}
