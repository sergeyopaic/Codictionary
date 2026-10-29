import '../../domain/exceptions/service_exceptions.dart';
import '../../domain/exceptions/storage_exceptions.dart';

/// One place for how failures are worded in the UI, so cards, the
/// explanation sheet and the editor say the same thing. Never shows raw
/// HTTP or JSON.

/// A few words for tight spaces such as a card ("no AI credit").
String failureShortReason(Object error) => switch (error) {
  StorageException() => 'not saved',
  ServiceException(:final failure) => switch (failure) {
    ServiceFailure.notConfigured => 'AI is off',
    ServiceFailure.network => 'offline',
    ServiceFailure.timeout => 'timed out',
    ServiceFailure.unauthorized => 'API key rejected',
    ServiceFailure.quotaExceeded => 'no AI credit',
    ServiceFailure.rateLimited => 'AI is busy',
    ServiceFailure.server => 'AI service error',
    ServiceFailure.incomplete => 'answer cut off',
    ServiceFailure.refused => 'AI declined',
    ServiceFailure.rejected ||
    ServiceFailure.invalidResponse => 'unexpected answer',
  },
  _ => 'something went wrong',
};

/// What happened and what the user can do about it.
String failureMessage(Object error) => switch (error) {
  StorageException(:final message) =>
    'The explanation was generated but could not be saved. $message',
  ServiceException(:final failure, :final message) =>
    '$message ${switch (failure) {
      ServiceFailure.notConfigured => 'Add an OpenAI API key to turn on explanations.',
      ServiceFailure.network => 'Check your internet connection, then try again.',
      ServiceFailure.timeout || ServiceFailure.rateLimited || ServiceFailure.server || ServiceFailure.incomplete => 'Try again in a moment.',
      ServiceFailure.unauthorized => 'Check the OpenAI API key in the .env file.',
      ServiceFailure.quotaExceeded => 'Add credit to the OpenAI account, then try again.',
      ServiceFailure.refused || ServiceFailure.rejected || ServiceFailure.invalidResponse => 'Try again; if it keeps failing, check the spelling of the word.',
    }}',
  _ => 'Something went wrong. Try again.',
};

/// Whether a "Try again" button can help right now. A missing or rejected
/// key needs a change outside the app first.
bool failureRetryHelps(Object error) => switch (error) {
  ServiceException(:final failure) =>
    failure != ServiceFailure.notConfigured &&
        failure != ServiceFailure.unauthorized,
  _ => true,
};
