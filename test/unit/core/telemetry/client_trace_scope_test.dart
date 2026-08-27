import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/core/telemetry/client_trace_scope.dart';
import 'package:al_rasikhoon/core/telemetry/telemetry_context.dart';

/// Stands in for the shared context holder plus the reporter that would be
/// reading it: `tagsNow()` is what a report filed at this instant would carry.
class _Holder {
  TelemetryContext value = const TelemetryContext(role: 'teacher');

  ClientTraceScope get scope =>
      ClientTraceScope(read: () => value, write: (updated) => value = updated);

  Map<String, String> tagsNow() => value.toTags();
}

void main() {
  test('a report filed while a callable is in flight carries the trace id', () {
    final holder = _Holder();
    Map<String, String>? tagsDuringCall;
    String? passedTraceId;

    return holder.scope
        .run((traceId) async {
          passedTraceId = traceId;
          tagsDuringCall = holder.tagsNow();
          return 'ok';
        })
        .then((_) {
          expect(tagsDuringCall!['clientTraceId'], passedTraceId);
          // The other context tags survive alongside it.
          expect(tagsDuringCall!['role'], 'teacher');
        });
  });

  test('the trace id is gone once a successful call completes', () async {
    final holder = _Holder();
    await holder.scope.run((_) async => 'ok');
    expect(holder.tagsNow().containsKey('clientTraceId'), isFalse);
  });

  test("a failed call's own error report still carries the trace id", () async {
    final holder = _Holder();
    String? mintedTraceId;
    Map<String, String>? tagsInCatch;

    try {
      await holder.scope.run((traceId) async {
        mintedTraceId = traceId;
        throw StateError('callable failed');
      });
    } catch (_) {
      // This is exactly where the real call sites file their report.
      tagsInCatch = holder.tagsNow();
    }

    expect(tagsInCatch['clientTraceId'], mintedTraceId);
  });

  test(
    'a failed call does not leak its trace id onto a later report',
    () async {
      final holder = _Holder();

      try {
        await holder.scope.run(
          (_) async => throw StateError('callable failed'),
        );
      } catch (_) {
        // Caller handles and moves on.
      }

      // Anything reported in a later turn of the event loop — an unrelated
      // provider failure, a crash minutes afterwards — must not inherit the id.
      await Future<void>.delayed(Duration.zero);

      expect(holder.tagsNow().containsKey('clientTraceId'), isFalse);
      expect(holder.tagsNow()['role'], 'teacher');
    },
  );

  test('two calls never share a trace id', () async {
    final holder = _Holder();
    final seen = <String>[];

    await holder.scope.run((traceId) async => seen.add(traceId));
    await holder.scope.run((traceId) async => seen.add(traceId));

    expect(seen.first, isNot(seen.last));
  });

  test(
    'a finishing call does not strip an overlapping call of its id',
    () async {
      final holder = _Holder();
      final releaseA = Completer<void>();
      final releaseB = Completer<void>();
      String? idB;

      // A starts and parks mid-flight.
      final a = holder.scope.run((_) async {
        await releaseA.future;
        return 'a';
      });

      // B starts while A is still in flight and takes over the live tag.
      final b = holder.scope.run((traceId) async {
        idB = traceId;
        await releaseB.future;
        return 'b';
      });

      // A finishes FIRST. Its clear must be a no-op: the live id is B's now.
      // Stripping it would leave a later report for B untagged, and the mirror
      // case would MIS-tag A's own report with B's id.
      releaseA.complete();
      await a;

      expect(holder.tagsNow()['clientTraceId'], idB);

      // B then finishes and does own the id, so it clears normally.
      releaseB.complete();
      await b;

      expect(holder.tagsNow().containsKey('clientTraceId'), isFalse);
    },
  );

  test('a failing call does not strip an overlapping call of its id', () async {
    final holder = _Holder();
    final releaseA = Completer<void>();
    final releaseB = Completer<void>();
    String? idB;

    final a = holder.scope.run((_) async {
      await releaseA.future;
      throw StateError('callable failed');
    });

    final b = holder.scope.run((traceId) async {
      idB = traceId;
      await releaseB.future;
      return 'b';
    });

    releaseA.complete();
    await expectLater(a, throwsStateError);
    // Past the deferred-clear turn that A schedules on failure.
    await Future<void>.delayed(Duration.zero);

    expect(holder.tagsNow()['clientTraceId'], idB);

    releaseB.complete();
    await b;
  });

  test(
    'the inert scope still mints an id but never touches the context',
    () async {
      final scope = ClientTraceScope.inert();
      String? traceId;
      await scope.run((id) async => traceId = id);
      expect(traceId, isNotNull);
    },
  );
}
