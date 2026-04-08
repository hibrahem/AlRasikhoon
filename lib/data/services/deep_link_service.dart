import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeepLinkService {
  final AppLinks _appLinks;
  final StreamController<Uri> _linkController = StreamController<Uri>.broadcast();

  DeepLinkService({AppLinks? appLinks})
      : _appLinks = appLinks ?? AppLinks();

  Stream<Uri> get linkStream => _linkController.stream;

  Future<void> init() async {
    if (kIsWeb) {
      // On web, check the current URL for an email sign-in link
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('oobCode')) {
        _linkController.add(uri);
      }
    } else {
      // On mobile: check for initial link (cold start)
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
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
