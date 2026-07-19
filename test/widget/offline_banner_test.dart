import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/shared/providers/connectivity_provider.dart';
import 'package:al_rasikhoon/shared/widgets/offline_banner.dart';

void main() {
  Widget host({required bool online}) => ProviderScope(
    overrides: [isConnectedProvider.overrideWithValue(online)],
    child: const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: OfflineBannerHost(child: Scaffold(body: Text('محتوى'))),
      ),
    ),
  );

  testWidgets('the banner shows while offline', (tester) async {
    await tester.pumpWidget(host(online: false));
    expect(find.textContaining('أنت غير متصل'), findsOneWidget);
    expect(find.text('محتوى'), findsOneWidget);
  });

  testWidgets('the banner is absent while online', (tester) async {
    await tester.pumpWidget(host(online: true));
    expect(find.textContaining('أنت غير متصل'), findsNothing);
    expect(find.text('محتوى'), findsOneWidget);
  });
}
