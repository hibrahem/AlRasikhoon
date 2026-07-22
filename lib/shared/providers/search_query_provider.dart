import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Query text behind a list screen's `AppSearchField`. Each screen declares
/// its own `NotifierProvider.autoDispose<SearchQueryNotifier, String>` so
/// searches are independent and reset when the screen is left.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}
