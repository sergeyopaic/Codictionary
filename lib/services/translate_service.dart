import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/exceptions/service_exceptions.dart';
import 'http/service_call.dart';

/// DeepL client for EN → RU translation.
///
/// Returns the translation or throws a [ServiceException].
class TranslateService {
  TranslateService(
    this.deeplApiKey, {
    http.Client? client,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 15),
    this.retry = const RetryPolicy(),
    Sleep? sleep,
  }) : _client = client ?? http.Client(),
       _endpoint = endpoint,
       _sleep = sleep ?? Future<void>.delayed;

  static const _service = 'DeepL';

  final String deeplApiKey;
  final Uri? _endpoint;
  final Duration timeout;
  final RetryPolicy retry;
  final http.Client _client;
  final Sleep _sleep;

  /// Free-plan keys end in ":fx" and only work on the free endpoint.
  Uri get endpoint =>
      _endpoint ??
      Uri.parse(
        deeplApiKey.trim().endsWith(':fx')
            ? 'https://api-free.deepl.com/v2/translate'
            : 'https://api.deepl.com/v2/translate',
      );

  /// False in local mode (no key): translations are typed by the user.
  bool get isConfigured => deeplApiKey.trim().isNotEmpty;

  Future<String> translateToRu(String text) async {
    if (!isConfigured) {
      throw const ServiceException(_service, ServiceFailure.notConfigured);
    }
    return callService(
      service: _service,
      timeout: timeout,
      retry: retry,
      sleep: _sleep,
      // DeepL no longer accepts `auth_key` in the body; the key goes in the
      // Authorization header. A map body is form-encoded by package:http.
      send: () => _client.post(
        endpoint,
        headers: {'Authorization': 'DeepL-Auth-Key ${deeplApiKey.trim()}'},
        body: {'text': text, 'source_lang': 'EN', 'target_lang': 'RU'},
      ),
      handle: _handle,
    );
  }

  static String _handle(http.Response response) {
    if (response.statusCode != 200) {
      final status = response.statusCode;
      throw ServiceException(_service, switch (status) {
        401 || 403 => ServiceFailure.unauthorized,
        456 => ServiceFailure.quotaExceeded,
        429 || 529 => ServiceFailure.rateLimited,
        408 => ServiceFailure.timeout,
        >= 500 => ServiceFailure.server,
        _ => ServiceFailure.rejected,
      }, statusCode: status);
    }
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      final text = ((data['translations'] as List).first as Map)['text'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
    } catch (_) {}
    throw const ServiceException(_service, ServiceFailure.invalidResponse);
  }
}
