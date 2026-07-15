import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/domain/session/session_duration.dart';

void main() {
  group('SessionDuration', () {
    test('a 1x target is twenty minutes, a 2x target is forty', () {
      expect(SessionDuration.targetForPace(1), const Duration(minutes: 20));
      expect(SessionDuration.targetForPace(2), const Duration(minutes: 40));
    });

    group('status', () {
      test('is none when there is no target', () {
        final d = SessionDuration(elapsed: const Duration(minutes: 22));
        expect(d.status, DurationStatus.none);
      });

      test('is onTarget within the ±25% band', () {
        final target = SessionDuration.targetForPace(1); // 20 min
        // 16..24 min inclusive is on target.
        expect(
          SessionDuration(
            elapsed: const Duration(minutes: 20),
            target: target,
          ).status,
          DurationStatus.onTarget,
        );
        expect(
          SessionDuration(
            elapsed: const Duration(minutes: 16),
            target: target,
          ).status,
          DurationStatus.onTarget,
        );
        expect(
          SessionDuration(
            elapsed: const Duration(minutes: 24),
            target: target,
          ).status,
          DurationStatus.onTarget,
        );
      });

      test('is under below the band and over above it', () {
        final target = SessionDuration.targetForPace(1); // 20 min
        expect(
          SessionDuration(
            elapsed: const Duration(minutes: 14),
            target: target,
          ).status,
          DurationStatus.under,
        );
        expect(
          SessionDuration(
            elapsed: const Duration(minutes: 26),
            target: target,
          ).status,
          DurationStatus.over,
        );
      });

      // The band edges themselves are INCLUSIVE: at 1x the target is 20 min, so
      // the lower edge is exactly 15 min and the upper exactly 25 min. Both
      // count as onTarget — a `<` → `<=` (or `>` → `>=`) slip in `status` would
      // push an exactly-on-edge session out of the band, so these two cases pin
      // the boundary that the 16/24 min cases inside the band cannot.
      test(
        'the exact lower band edge (15 min at 1x) is onTarget, not under',
        () {
          final target = SessionDuration.targetForPace(1); // 20 min, lower = 15
          expect(
            SessionDuration(
              elapsed: const Duration(minutes: 15),
              target: target,
            ).status,
            DurationStatus.onTarget,
          );
        },
      );

      test(
        'the exact upper band edge (25 min at 1x) is onTarget, not over',
        () {
          final target = SessionDuration.targetForPace(1); // 20 min, upper = 25
          expect(
            SessionDuration(
              elapsed: const Duration(minutes: 25),
              target: target,
            ).status,
            DurationStatus.onTarget,
          );
        },
      );

      // One second past each edge falls out of the band — the companion to the
      // inclusive-edge cases above, proving the edge is the LAST onTarget value.
      test('one second below the lower edge is under', () {
        final target = SessionDuration.targetForPace(1); // 20 min, lower = 15
        expect(
          SessionDuration(
            elapsed: const Duration(minutes: 14, seconds: 59),
            target: target,
          ).status,
          DurationStatus.under,
        );
      });

      test('one second above the upper edge is over', () {
        final target = SessionDuration.targetForPace(1); // 20 min, upper = 25
        expect(
          SessionDuration(
            elapsed: const Duration(minutes: 25, seconds: 1),
            target: target,
          ).status,
          DurationStatus.over,
        );
      });
    });

    test('elapsed is clamped to three times the target', () {
      final target = SessionDuration.targetForPace(1); // 20 min, cap 60 min
      final d = SessionDuration(
        elapsed: const Duration(hours: 12),
        target: target,
      );
      expect(d.elapsed, const Duration(minutes: 60));
      expect(d.status, DurationStatus.over);
    });

    // The cap itself is a legal length: an elapsed of exactly 3× the target
    // (60 min at 1x) is NOT over the cap, so it is stored verbatim rather than
    // re-clamped. This pins the `elapsed > cap` boundary — a `>` → `>=` slip
    // would leave the value unchanged here but this documents the intent.
    test('elapsed exactly at the cap is kept, not clamped away', () {
      final target = SessionDuration.targetForPace(1); // 20 min, cap 60 min
      final d = SessionDuration(
        elapsed: const Duration(minutes: 60),
        target: target,
      );
      expect(d.elapsed, const Duration(minutes: 60));
      expect(d.status, DurationStatus.over);
    });

    test('one second past the cap is clamped back to the cap', () {
      final target = SessionDuration.targetForPace(1); // 20 min, cap 60 min
      final d = SessionDuration(
        elapsed: const Duration(minutes: 60, seconds: 1),
        target: target,
      );
      expect(d.elapsed, const Duration(minutes: 60));
    });

    test('without a target elapsed is stored raw, uncapped', () {
      final d = SessionDuration(elapsed: const Duration(hours: 3));
      expect(d.elapsed, const Duration(hours: 3));
    });

    group('formatting', () {
      test('clock is zero-padded mm:ss', () {
        expect(
          SessionDuration.formatClock(const Duration(minutes: 12, seconds: 5)),
          '12:05',
        );
        expect(SessionDuration.formatClock(Duration.zero), '00:00');
      });

      test('clock getter shows the elapsed length with its seconds', () {
        // Seconds are part of the display — 22:20 must NOT round to 22 minutes.
        final d = SessionDuration(
          elapsed: const Duration(minutes: 22, seconds: 20),
        );
        expect(d.clock, '22:20');
      });
    });

    group('liveTimerLevel', () {
      final target = SessionDuration.targetForPace(1); // 20 min
      test('is neutral with no target', () {
        expect(
          SessionDuration.liveTimerLevel(const Duration(hours: 5), null),
          LiveTimerLevel.neutral,
        );
      });
      test(
        'is neutral below target, warning at target, danger at twice target',
        () {
          expect(
            SessionDuration.liveTimerLevel(const Duration(minutes: 10), target),
            LiveTimerLevel.neutral,
          );
          expect(
            SessionDuration.liveTimerLevel(const Duration(minutes: 20), target),
            LiveTimerLevel.warning,
          );
          expect(
            SessionDuration.liveTimerLevel(const Duration(minutes: 40), target),
            LiveTimerLevel.danger,
          );
        },
      );
    });

    group('fromRecord', () {
      test('is null when the record captured no timing', () {
        expect(
          SessionDuration.fromRecord(
            const _FakeTiming(duration: null, paceAtTime: 1),
          ),
          isNull,
        );
      });

      test('targets 20 min × paceAtTime for a paced record', () {
        // A 2x record targets 40 min, so a 40 min session is onTarget — proof
        // the factory scaled the target by paceAtTime rather than hardcoding 1x.
        final d = SessionDuration.fromRecord(
          const _FakeTiming(duration: Duration(minutes: 40), paceAtTime: 2),
        );
        expect(d, isNotNull);
        expect(d!.target, const Duration(minutes: 40));
        expect(d.status, DurationStatus.onTarget);
      });

      test('clamps the elapsed time to the paced cap on construction', () {
        // 1x cap is 3 × 20 = 60 min; a forgotten 5-hour session is recorded as
        // the clamped maximum, matching the value-object invariant.
        final d = SessionDuration.fromRecord(
          const _FakeTiming(duration: Duration(hours: 5), paceAtTime: 1),
        );
        expect(d!.elapsed, const Duration(minutes: 60));
      });
    });
  });
}

/// A stand-in [SessionTiming] so the domain test never reaches for the
/// data-layer record model that implements it in production.
class _FakeTiming implements SessionTiming {
  @override
  final Duration? duration;
  @override
  final int paceAtTime;
  const _FakeTiming({required this.duration, required this.paceAtTime});
}
