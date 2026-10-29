import 'dart:async';

import 'package:http/http.dart' as http;

import '../../domain/exceptions/service_exceptions.dart';

typedef Sleep = Future<void> Function(Duration);

/// How often a temporary failure is retried.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 8),
  });

  /// Total attempts including the first one.
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;

  static const none = RetryPolicy(maxAttempts: 1);

  Duration delayBefore(int nextAttempt) {
    final ms = baseDelay.inMilliseconds * (1 << (nextAttempt - 2));
    return Duration(milliseconds: ms.clamp(0, maxDelay.inMilliseconds));
  }
}

/// Runs one HTTP call with a time limit and limited retries.
///
/// * [send] performs the request; [handle] turns a response into a result or
///   throws a [ServiceException].
/// * Only network errors, rate limits and server errors are retried. A
///   timeout is not retried, so the total wait stays bounded; quota and key
///   errors are not retried because repeating cannot fix them.
Future<T> callService<T>({
  required String service,
  required Future<http.Response> Function() send,
  required T Function(http.Response response) handle,
  required Duration timeout,
  required RetryPolicy retry,
  required Sleep sleep,
}) async {
  for (var attempt = 1; ; attempt++) {
    try {
      final http.Response response;
      try {
        response = await send().timeout(timeout);
      } on TimeoutException {
        throw ServiceException(service, ServiceFailure.timeout);
      } on http.ClientException {
        // Connection refused/reset, DNS failure, offline (IO and browser).
        throw ServiceException(service, ServiceFailure.network);
      }
      return handle(response);
    } on ServiceException catch (e) {
      final retryable = switch (e.failure) {
        ServiceFailure.network ||
        ServiceFailure.rateLimited ||
        ServiceFailure.server => true,
        _ => false,
      };
      if (!retryable || attempt >= retry.maxAttempts) rethrow;
      await sleep(retry.delayBefore(attempt + 1));
    }
  }
}
