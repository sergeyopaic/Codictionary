import 'dart:convert';
import 'package:http/http.dart' as http;

class GptService {
  final String apiKey;
  GptService(this.apiKey);

  static const _url = 'https://api.openai.com/v1/responses';

  Future<String> sendPrompt(String prompt) async {
    final resp = await http.post(
      Uri.parse(_url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4.1-mini',
        'input': prompt,
        'temperature': 1,
        'max_output_tokens': 400,
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('OpenAI error: ${resp.statusCode} ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    final output = data['output'] as List<dynamic>? ?? const [];
    if (output.isEmpty) return 'No output from model.';
    final first = output.first as Map<String, dynamic>?;
    final content = first?['content'] as List<dynamic>? ?? const [];
    for (final part in content) {
      final p = part as Map<String, dynamic>;
      if (p['text'] is String) return p['text'] as String;
    }
    return 'No text in response.';
  }

  Future<String> explainWord(String eng) async {
    final prompt =
        'Приведи пример использования слова "$eng" на английском языке. '
        'Дай русскоязычное описание длиной примерно 200 слов о том, как это слово переводится и где используется.';
    return sendPrompt(prompt);
  }
}
