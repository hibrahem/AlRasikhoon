/// Pure, dependency-free redaction helpers.
///
/// These run on every message and route before it leaves the device. They are
/// the last line of defence behind [TelemetryContext]'s closed field set:
/// FirebaseException messages routinely embed document paths, and go_router
/// locations embed student ids.
library;

import '../constants/app_constants.dart';

const String _redactedLocalPart = '<redacted>';

final RegExp _syntheticEmail = RegExp(
  r'[A-Za-z0-9._%+-]+@' + RegExp.escape(AppConstants.synthesizedEmailDomain),
);

final RegExp _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

final RegExp _alphanumericOnly = RegExp(r'^[A-Za-z0-9]+$');

/// A path segment is treated as an identifier when it is a UUID, or when it is
/// long AND made up of letters and digits only. Purely-alphanumeric is what
/// keeps legitimate route names intact: route names are hyphenated words
/// (`/account-not-found` is 17 characters but contains a hyphen), while a
/// Firestore auto-id is a 20-character unbroken base62 token with no
/// separators — and, roughly 3% of the time, no digit either, so a digit
/// requirement alone is not a reliable discriminator.
bool _looksLikeIdentifier(String segment) {
  if (_uuid.hasMatch(segment)) return true;
  return segment.length >= 16 && _alphanumericOnly.hasMatch(segment);
}

/// Replaces identifier-looking segments in a `/`-delimited path with `:id`.
String templateRoute(String route) {
  final query = route.indexOf('?');
  final path = query == -1 ? route : route.substring(0, query);
  final templated = path
      .split('/')
      .map((segment) => _looksLikeIdentifier(segment) ? ':id' : segment)
      .join('/');
  // Query strings can carry ids too, and nothing downstream needs them.
  return templated;
}

/// Redacts synthetic login addresses and document ids from a free-form
/// message. Safe to call on any string, including an empty one.
String scrubMessage(String input) {
  final withoutEmails = input.replaceAllMapped(
    _syntheticEmail,
    (_) => '$_redactedLocalPart@${AppConstants.synthesizedEmailDomain}',
  );
  return withoutEmails
      .split(' ')
      .map((token) => token.contains('/') ? templateRoute(token) : token)
      .join(' ');
}

String errorsBucket(int count) {
  if (count <= 0) return '0';
  if (count <= 3) return '1-3';
  if (count <= 10) return '4-10';
  return '10+';
}

String durationBucket(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 5) return '<5m';
  if (minutes <= 15) return '5-15m';
  if (minutes <= 30) return '15-30m';
  return '30m+';
}

String pendingBucket(int count) {
  if (count <= 1) return '1';
  if (count <= 5) return '2-5';
  if (count <= 20) return '6-20';
  return '20+';
}
