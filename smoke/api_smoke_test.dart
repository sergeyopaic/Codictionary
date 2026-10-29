// One real request to each paid API, to check that keys, endpoints and
// response parsing still work. Not part of `flutter test` (it only runs
// test/); run it by hand or with the "API smoke (manual)" workflow:
//
//   OPENAI_API_KEY=... DEEPL_API_KEY=... flutter test --no-pub smoke
//
// A service whose key is not set is skipped, not failed.
import 'dart:io';

import 'package:codictionary/data/remote/deepl_translator.dart';
import 'package:codictionary/data/remote/openai_explainer.dart';
import 'package:flutter_test/flutter_test.dart';

String? _key(String name) {
  final value = Platform.environment[name]?.trim() ?? '';
  return value.isEmpty ? null : value;
}

final _cyrillic = RegExp('[а-яё]', caseSensitive: false);

void main() {
  final openAiKey = _key('OPENAI_API_KEY');
  final deeplKey = _key('DEEPL_API_KEY');

  test(
    'OpenAI explains a word in Russian',
    () async {
      final text = await OpenAiExplainer(openAiKey!).explainShort('apple');
      expect(text.trim(), isNotEmpty);
      expect(text, contains(_cyrillic));
    },
    skip: openAiKey == null ? 'OPENAI_API_KEY is not set' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'DeepL translates a word to Russian',
    () async {
      final text = await DeepLTranslator(deeplKey!).translateToRu('apple');
      expect(text.trim(), isNotEmpty);
      expect(text, contains(_cyrillic));
    },
    skip: deeplKey == null ? 'DEEPL_API_KEY is not set' : false,
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
