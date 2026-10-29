import '../../domain/exceptions/service_exceptions.dart';

/// Whether a "Try again" button can help right now. A missing or rejected
/// key needs a change outside the app first. (Wording of failures lives in
/// `AppStrings`.)
bool failureRetryHelps(Object error) => switch (error) {
  ServiceException(:final failure) =>
    failure != ServiceFailure.notConfigured &&
        failure != ServiceFailure.unauthorized,
  _ => true,
};
