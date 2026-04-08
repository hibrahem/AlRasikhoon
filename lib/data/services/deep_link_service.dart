import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeepLinkService {
  final AppLinks _appLinks;
  final StreamController<Uri> _linkController = StreamController<Uri>.broadcast();

  /// Stores the initial link for late subscribers (e.g., web cold start).
  Uri? _initialLink;

  DeepLinkService({AppLinks? appLinks})
      : _appLinks = appLinks ?? AppLinks();

  Stream<Uri> get linkStream => _linkController.stream;

  /// Returns the initial link captured at startup (if any).
  /// Consumers should call this once and then listen to [linkStream].
  Uri? consumeInitialLink() {
    final link = _initialLink;
    _initialLink = null;
    return link;
  }

  Future<void> init() async {
    if (kIsWeb) {
      // On web, check the current URL for an email sign-in link.
      // Firebase email link URLs contain mode=signIn and oobCode params.
      final uri = Uri.base;
      final fullUrl = uri.toString();
      if (fullUrl.contains('oobCode') || fullUrl.contains('mode=signIn')) {
        _initialLink = uri;
        _linkController.add(uri);
      }
    } else {
      // On mobile: check for initial link (cold start)
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _initialLink = initialLink;
        _linkController.add(initialLink);
      }

      // Listen for subsequent links (warm start)
      _appLinks.uriLinkStream.listen((uri) {
        _linkController.add(uri);
      });
    }
  }

  void dispose() {
    _linkController.close();
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService();
  ref.onDispose(() => service.dispose());
  return service;
});
