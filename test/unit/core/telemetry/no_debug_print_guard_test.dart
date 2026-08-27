import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no debugPrint survives under lib because telemetry replaced it', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('debugPrint(')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Provider failures are captured by TelemetryProviderObserver and '
          'errors by ErrorReporter. debugPrint is a no-op in release builds, '
          'so it reports nothing in production. Offenders:\n'
          '${offenders.join('\n')}',
    );
  });
}
