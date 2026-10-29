import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/exceptions/service_exceptions.dart';
import '../../domain/services/word_explainer.dart';
import 'service_call.dart';

/// OpenAI Responses API client for word explanations.
///
/// Returns explanation text or throws a [ServiceException]; it never returns
/// a diagnostic string that could be stored as an explanation.
class OpenAiExplainer implements WordExplainer {
  OpenAiExplainer(
    this.apiKey, {
    http.Client? client,
    Uri? endpoint,
    this.model = 'gpt-4.1-mini',
    this.timeout = const Duration(seconds: 30),
    this.retry = const RetryPolicy(),
    Sleep? sleep,
  }) : _client = client ?? http.Client(),
       endpoint = endpoint ?? Uri.parse('https://api.openai.com/v1/responses'),
       _sleep = sleep ?? Future<void>.delayed;

  static const _service = 'OpenAI';

  final String apiKey;
  final Uri endpoint;
  final String model;
  final Duration timeout;
  final RetryPolicy retry;
  final http.Client _client;
  final Sleep _sleep;

  @override
  bool get isAvailable => apiKey.trim().isNotEmpty;

  Future<String> sendPrompt(String prompt, {int maxTokens = 400}) async {
    if (!isAvailable) {
      throw const ServiceException(_service, ServiceFailure.notConfigured);
    }
    return callService(
      service: _service,
      timeout: timeout,
      retry: retry,
      sleep: _sleep,
      send: () => _client.post(
        endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'input': prompt,
          'temperature': 1,
          'max_output_tokens': maxTokens,
        }),
      ),
      handle: _handle,
    );
  }

  static String _handle(http.Response response) {
    if (response.statusCode != 200) throw _error(response);

    final Map<String, dynamic> json;
    try {
      // Decode as UTF-8 whatever the headers say; a missing charset would
      // otherwise turn Cyrillic into mojibake.
      json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const ServiceException(_service, ServiceFailure.invalidResponse);
    }

    // Collect every text part of every message item; other item types
    // (e.g. reasoning) carry no answer text.
    final messages = <String>[];
    var refused = false;
    final output = json['output'];
    if (output is List) {
      for (final item in output) {
        if (item is! Map || item['type'] != 'message') continue;
        final parts = StringBuffer();
        final content = item['content'];
        if (content is! List) continue;
        for (final part in content) {
          if (part is! Map) continue;
          if (part['type'] == 'output_text' && part['text'] is String) {
            parts.write(part['text']);
          } else if (part['type'] == 'refusal') {
            refused = true;
          }
        }
        if (parts.isNotEmpty) messages.add(parts.toString());
      }
    }

    switch (json['status']) {
      case 'incomplete':
        throw ServiceException(
          _service,
          ServiceFailure.incomplete,
          providerCode: _str((json['incomplete_details'] as Map?)?['reason']),
        );
      case 'failed' || 'cancelled':
        throw const ServiceException(_service, ServiceFailure.server);
    }

    final text = messages.join('\n').trim();
    if (text.isEmpty) {
      throw ServiceException(
        _service,
        refused ? ServiceFailure.refused : ServiceFailure.invalidResponse,
      );
    }
    return text;
  }

  static ServiceException _error(http.Response response) {
    String? code;
    try {
      final error =
          (jsonDecode(utf8.decode(response.bodyBytes)) as Map)['error'];
      if (error is Map) code = _str(error['code']) ?? _str(error['type']);
    } catch (_) {}

    const quotaCodes = {
      'insufficient_quota',
      'billing_hard_limit_reached',
      'credit_balance_exhausted',
    };
    final status = response.statusCode;
    final failure = switch (status) {
      401 || 403 => ServiceFailure.unauthorized,
      402 => ServiceFailure.quotaExceeded,
      429 when quotaCodes.contains(code) => ServiceFailure.quotaExceeded,
      429 => ServiceFailure.rateLimited,
      408 => ServiceFailure.timeout,
      >= 500 => ServiceFailure.server,
      _ => ServiceFailure.rejected,
    };
    return ServiceException(
      _service,
      failure,
      statusCode: status,
      providerCode: code,
    );
  }

  static String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

  /// Generates a concise explanation about the English word [eng].
  /// About 3x shorter than the detailed version.
  @override
  Future<String> explainShort(String eng) async {
    final prompt =
        "Ты — полезный словарный ассистент. Дай короткое, ёмкое объяснение английского слова '"
        "$eng' на русском языке: значение, 1–2 простых примера, типичное употребление/нюанс. "
        "Пиши кратко и по делу — примерно в 3 раза короче подробного объяснения. Ответ только на русском. "
        "Не используй Markdown и не используй символы * или **; выводи простой чистый текст.";
    // Room for a complete short answer in Russian; a cut-off answer is
    // reported as an error rather than stored.
    return sendPrompt(prompt, maxTokens: 320);
  }

  /// Generates a detailed, extended explanation about the word [eng].
  @override
  Future<String> explainLong(String eng) async {
    final prompt =
        "Ты — полезный словарный ассистент. Дай подробное, структурированное объяснение английского слова '"
        "$eng' на русском языке: основные значения/оттенки, регистр/нюансы, синонимы/антонимы, частые коллокации, 3–4 "
        "кратких практических примера, типичные ошибки и ловушки. Делай абзацы короткими, используй маркеры, где уместно. "
        "Ответ только на русском. Не используй Markdown и не используй символы * или **; выводи простой чистый текст.";
    return sendPrompt(prompt, maxTokens: 1100);
  }
}
