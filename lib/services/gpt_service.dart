import 'dart:convert';
import 'package:http/http.dart' as http;

class GptService {
  final String apiKey;
  GptService(this.apiKey);

  static const _url = 'https://api.openai.com/v1/responses';

  Future<String> sendPrompt(String prompt, {int maxTokens = 400}) async {
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
        'max_output_tokens': maxTokens,
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

  /// Backward-compatible: default explanation now returns a short version.
  Future<String> explainWord(String eng) => explainWordShort(eng);

  /// Generates a concise explanation about the English word [eng].
  /// About 3x shorter than the detailed version.
  Future<String> explainWordShort(String eng) async {
    final prompt =
        "Ты — полезный словарный ассистент. Дай короткое, ёмкое объяснение английского слова '"
        "$eng' на русском языке: значение, 1–2 простых примера, типичное употребление/нюанс. "
        "Пиши кратко и по делу — примерно в 3 раза короче подробного объяснения. Ответ только на русском. "
        "Не используй Markdown и не используй символы * или **; выводи простой чистый текст.";
    return sendPrompt(prompt, maxTokens: 220);
  }

  /// Generates a detailed, extended explanation about the word [eng].
  Future<String> explainWordLong(String eng) async {
    final prompt =
        "Ты — полезный словарный ассистент. Дай подробное, структурированное объяснение английского слова '"
        "$eng' на русском языке: основные значения/оттенки, регистр/нюансы, синонимы/антонимы, частые коллокации, 3–4 "
        "кратких практических примера, типичные ошибки и ловушки. Делай абзацы короткими, используй маркеры, где уместно. "
        "Ответ только на русском. Не используй Markdown и не используй символы * или **; выводи простой чистый текст.";
    return sendPrompt(prompt, maxTokens: 700);
  }
}
