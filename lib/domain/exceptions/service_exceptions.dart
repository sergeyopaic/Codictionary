/// What went wrong when calling an external service (translation or AI).
enum ServiceFailure {
  /// No API key or endpoint is configured; no request was made.
  notConfigured,

  /// The service could not be reached (offline, DNS, connection reset).
  network,

  /// No answer within the time limit.
  timeout,

  /// The key was rejected or access is not allowed.
  unauthorized,

  /// The account is out of credit or over its quota. Not retried.
  quotaExceeded,

  /// Too many requests for now; worth trying again later.
  rateLimited,

  /// The service failed on its side (5xx).
  server,

  /// The service refused the request as invalid (4xx other than the above).
  rejected,

  /// The answer could not be understood or contained no text.
  invalidResponse,

  /// The answer was cut off before it was complete.
  incomplete,

  /// The model declined to answer.
  refused,
}

/// A failed call to an external service. [message] is safe to show to the
/// user: it never contains API keys or the raw provider response.
class ServiceException implements Exception {
  const ServiceException(
    this.service,
    this.failure, {
    this.statusCode,
    this.providerCode,
  });

  /// "OpenAI" or "DeepL".
  final String service;
  final ServiceFailure failure;

  /// HTTP status, if a response was received.
  final int? statusCode;

  /// The provider's machine-readable error code (e.g. `insufficient_quota`),
  /// for diagnostics. Never the raw response body.
  final String? providerCode;

  /// Whether trying again later may help.
  bool get isTemporary => switch (failure) {
    ServiceFailure.network ||
    ServiceFailure.timeout ||
    ServiceFailure.rateLimited ||
    ServiceFailure.server ||
    ServiceFailure.incomplete => true,
    _ => false,
  };

  String get message => switch (failure) {
    ServiceFailure.notConfigured => '$service is not set up in this app.',
    ServiceFailure.network =>
      'Could not reach $service. Check your internet connection.',
    ServiceFailure.timeout => '$service took too long to answer.',
    ServiceFailure.unauthorized => '$service rejected the API key.',
    ServiceFailure.quotaExceeded =>
      'The $service account has run out of credit or quota.',
    ServiceFailure.rateLimited =>
      '$service is busy right now. Try again in a moment.',
    ServiceFailure.server => '$service is having problems. Try again later.',
    ServiceFailure.rejected => '$service could not process this request.',
    ServiceFailure.invalidResponse =>
      '$service returned an answer the app could not read.',
    ServiceFailure.incomplete =>
      '$service stopped before finishing the answer.',
    ServiceFailure.refused => '$service declined to answer.',
  };

  @override
  String toString() => message;
}
