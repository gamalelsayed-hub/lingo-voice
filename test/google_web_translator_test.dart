import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lingo_voice/services/google_web_translator.dart';

void main() {
  test('joins the translated segments', () async {
    late Uri asked;
    final translator = GoogleWebTranslator(
      client: MockClient((r) async {
        asked = r.url;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              [
                ['I want to go to work tomorrow, ', 'عايز أروح الشغل بكرة'],
                ['but I am not sure.', 'بس مش متأكد'],
              ],
              null,
              'ar',
            ]),
          ),
          200,
        );
      }),
    );

    final english = await translator.translate(
      'عايز أروح الشغل بكرة بس مش متأكد',
      from: 'ar',
      to: 'en',
    );

    expect(english, 'I want to go to work tomorrow, but I am not sure.');
    expect(asked.queryParameters['sl'], 'ar');
    expect(asked.queryParameters['tl'], 'en');
  });

  test('throws when Google blocks the request', () {
    final translator = GoogleWebTranslator(
      client: MockClient((_) async => http.Response('blocked', 429)),
    );
    expect(
      translator.translate('أهلاً', from: 'ar', to: 'en'),
      throwsException,
    );
  });
}
