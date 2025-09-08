import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslateService {
  final String deeplApiKey;
  TranslateService(this.deeplApiKey);

  static const _url = 'https://api-free.deepl.com/v2/translate';

  Future<String> translateToRu(String text) async {
    final resp = await http.post(
      Uri.parse(_url),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'auth_key=$deeplApiKey&text=$text&target_lang=RU',
    );

    if (resp.statusCode != 200) {
      throw Exception('DeepL error: ${resp.body}');
    }
    final data = jsonDecode(resp.body);
    return data['translations'][0]['text'] as String;
  }
}
