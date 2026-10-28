import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:codictionary/domain/exceptions/service_exceptions.dart';
import 'package:codictionary/services/gpt_service.dart';
import 'package:codictionary/services/http/service_call.dart';
import 'package:codictionary/services/translate_service.dart';

const _key = 'sk-test-SECRET-KEY';

/// JSON as UTF-8 bytes *without* a Content-Type header, as a proxy or
/// gateway may send it. package:http would then decode it as Latin-1.
http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

Map<String, Object?> _message(List<Map<String, Object?>> parts) => {
  'type': 'message',
  'content': parts,
};

Map<String, Object?> _text(String text) => {
  'type': 'output_text',
  'text': text,
};

Map<String, Object?> _response(
  List<Map<String, Object?>> output, {
  String status = 'completed',
}) => {'status': status, 'output': output};

Matcher _fails(ServiceFailure failure) => throwsA(
  isA<ServiceException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  late int calls;
  late List<Duration> sleeps;

  setUp(() {
    calls = 0;
    sleeps = [];
  });

  GptService gpt(
    FutureOr<http.Response> Function(http.Request) handler, {
    String key = _key,
    Duration timeout = const Duration(seconds: 5),
  }) => GptService(
    key,
    client: MockClient((r) async {
      calls++;
      return handler(r);
    }),
    timeout: timeout,
    sleep: (d) async => sleeps.add(d),
  );

  TranslateService deepl(
    FutureOr<http.Response> Function(http.Request) handler, {
    String key = 'deepl-key:fx',
    Uri? endpoint,
  }) => TranslateService(
    key,
    client: MockClient((r) async {
      calls++;
      return handler(r);
    }),
    endpoint: endpoint,
    sleep: (d) async => sleeps.add(d),
  );

  group('OpenAI', () {
    test('joins every text part of every message item', () async {
      final client = gpt(
        (_) => _json(
          _response([
            {'type': 'reasoning', 'summary': []},
            _message([
              _text('Стойкий — '),
              _text('способный восстанавливаться.'),
            ]),
            _message([_text('Пример: Kids are resilient.')]),
          ]),
        ),
      );

      expect(
        await client.explainWordShort('resilient'),
        'Стойкий — способный восстанавливаться.\nПример: Kids are resilient.',
      );
    });

    test(
      'sends the key as a bearer token to the configured endpoint',
      () async {
        late http.Request sent;
        final client = GptService(
          _key,
          endpoint: Uri.parse('https://gateway.test/explain'),
          client: MockClient((r) async {
            sent = r;
            return _json(
              _response([
                _message([_text('ok')]),
              ]),
            );
          }),
        );

        await client.explainWordShort('apple');

        expect(sent.url.toString(), 'https://gateway.test/explain');
        expect(sent.headers['Authorization'], 'Bearer $_key');
      },
    );

    test('a missing key fails without any request', () async {
      final client = gpt((_) => _json({}), key: '  ');

      await expectLater(
        client.explainWordShort('apple'),
        _fails(ServiceFailure.notConfigured),
      );
      expect(calls, 0);
    });

    for (final (status, failure) in [
      (401, ServiceFailure.unauthorized),
      (403, ServiceFailure.unauthorized),
      (400, ServiceFailure.rejected),
    ]) {
      test('HTTP $status is $failure and not retried', () async {
        final client = gpt((_) => _json({'error': {}}, status));
        await expectLater(client.explainWordShort('apple'), _fails(failure));
        expect(calls, 1);
      });
    }

    test('an exhausted balance is reported and not retried', () async {
      final client = gpt(
        (_) => _json({
          'error': {'code': 'insufficient_quota', 'type': 'insufficient_quota'},
        }, 429),
      );

      await expectLater(
        client.explainWordShort('apple'),
        throwsA(
          isA<ServiceException>()
              .having((e) => e.failure, 'failure', ServiceFailure.quotaExceeded)
              .having((e) => e.providerCode, 'code', 'insufficient_quota'),
        ),
      );
      expect(calls, 1);
    });

    test('a rate limit is retried with growing delays', () async {
      final client = gpt(
        (_) => calls < 3
            ? _json({
                'error': {'code': 'rate_limit_exceeded'},
              }, 429)
            : _json(
                _response([
                  _message([_text('ok')]),
                ]),
              ),
      );

      expect(await client.explainWordShort('apple'), 'ok');
      expect(calls, 3);
      expect(sleeps, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    });

    test('server errors give up after a bounded number of attempts', () async {
      final client = gpt((_) => http.Response('oops', 503));

      await expectLater(
        client.explainWordShort('apple'),
        _fails(ServiceFailure.server),
      );
      expect(calls, const RetryPolicy().maxAttempts);
    });

    test('network failures are retried, then reported', () async {
      final client = gpt((_) => throw http.ClientException('connection reset'));

      await expectLater(
        client.explainWordShort('apple'),
        _fails(ServiceFailure.network),
      );
      expect(calls, 3);
    });

    test('a hanging request times out instead of waiting forever', () async {
      final never = Completer<http.Response>();
      final client = gpt(
        (_) => never.future,
        timeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        client.explainWordShort('apple'),
        _fails(ServiceFailure.timeout),
      );
      expect(calls, 1, reason: 'timeouts are not retried');
    });

    test('an empty answer is an error, not an explanation', () async {
      for (final body in [
        _response([]),
        _response([
          _message([_text('   ')]),
        ]),
        {'output': 'nonsense'},
      ]) {
        await expectLater(
          gpt((_) => _json(body)).explainWordShort('apple'),
          _fails(ServiceFailure.invalidResponse),
        );
      }
    });

    test('invalid JSON is an error', () async {
      await expectLater(
        gpt((_) => http.Response('{not json', 200)).explainWordShort('apple'),
        _fails(ServiceFailure.invalidResponse),
      );
    });

    test('a cut-off answer is reported as incomplete', () async {
      final client = gpt(
        (_) => _json({
          ..._response([
            _message([_text('Стойкий — спос')]),
          ], status: 'incomplete'),
          'incomplete_details': {'reason': 'max_output_tokens'},
        }),
      );

      await expectLater(
        client.explainWordShort('apple'),
        throwsA(
          isA<ServiceException>()
              .having((e) => e.failure, 'failure', ServiceFailure.incomplete)
              .having((e) => e.providerCode, 'code', 'max_output_tokens'),
        ),
      );
    });

    test('a refusal is reported as refused', () async {
      final client = gpt(
        (_) => _json(
          _response([
            _message([
              {'type': 'refusal', 'refusal': 'no'},
            ]),
          ]),
        ),
      );

      await expectLater(
        client.explainWordShort('apple'),
        _fails(ServiceFailure.refused),
      );
    });

    test('errors never expose the key or the raw response', () async {
      final client = gpt(
        (_) => _json({
          'error': {'message': 'Incorrect API key provided: $_key RAW-BODY'},
        }, 401),
      );

      try {
        await client.explainWordShort('apple');
        fail('expected an error');
      } on ServiceException catch (e) {
        expect('$e ${e.message}', isNot(contains('SECRET')));
        expect('$e ${e.message}', isNot(contains('RAW-BODY')));
      }
    });
  });

  group('DeepL', () {
    test('free keys use the free endpoint with header auth', () async {
      late http.Request sent;
      final client = deepl((r) {
        sent = r;
        return _json({
          'translations': [
            {'text': 'рок-н-ролл'},
          ],
        });
      });

      expect(await client.translateToRu('rock & roll'), 'рок-н-ролл');
      expect(sent.url.host, 'api-free.deepl.com');
      expect(sent.headers['Authorization'], 'DeepL-Auth-Key deepl-key:fx');
      expect(sent.bodyFields['text'], 'rock & roll');
      expect(sent.body, isNot(contains('auth_key')));
    });

    test('pro keys use the pro endpoint; an override wins', () async {
      expect(TranslateService('pro-key').endpoint.host, 'api.deepl.com');
      expect(
        TranslateService(
          'pro-key',
          endpoint: Uri.parse('https://gateway.test/translate'),
        ).endpoint.host,
        'gateway.test',
      );
    });

    for (final (status, failure) in [
      (403, ServiceFailure.unauthorized),
      (456, ServiceFailure.quotaExceeded),
      (400, ServiceFailure.rejected),
    ]) {
      test('HTTP $status is $failure', () async {
        await expectLater(
          deepl((_) => http.Response('', status)).translateToRu('apple'),
          _fails(failure),
        );
        expect(calls, 1);
      });
    }

    test('busy and server errors are retried', () async {
      final client = deepl(
        (_) => calls == 1
            ? http.Response('', 429)
            : calls == 2
            ? http.Response('', 500)
            : _json({
                'translations': [
                  {'text': 'яблоко'},
                ],
              }),
      );

      expect(await client.translateToRu('apple'), 'яблоко');
      expect(calls, 3);
    });

    test('a response without a translation is an error', () async {
      for (final body in [
        <String, Object?>{},
        {'translations': []},
        {
          'translations': [
            {'text': ''},
          ],
        },
      ]) {
        await expectLater(
          deepl((_) => _json(body)).translateToRu('apple'),
          _fails(ServiceFailure.invalidResponse),
        );
      }
    });

    test('a missing key fails without any request', () async {
      await expectLater(
        deepl((_) => _json({}), key: '').translateToRu('apple'),
        _fails(ServiceFailure.notConfigured),
      );
      expect(calls, 0);
    });
  });
}
