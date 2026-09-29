import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslateService {
  final String deeplApiKey;
  TranslateService(this.deeplApiKey);

  static const _url = 'https://api-free.deepl.com/v2/translate';

  Future<String> translateToRu(String text) async {
    // DeepL no longer accepts `auth_key` in the body; the key goes in the
    // Authorization header. A map body is form-encoded by package:http.
    final resp = await http.post(
      Uri.parse(_url),
      headers: {'Authorization': 'DeepL-Auth-Key $deeplApiKey'},
      body: {'text': text, 'source_lang': 'EN', 'target_lang': 'RU'},
    );

    if (resp.statusCode != 200) {
      throw Exception('DeepL error: ${resp.statusCode} ${resp.body}');
    }
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    return data['translations'][0]['text'] as String;
  }
}
