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

      test('arabic minutes label rounds to the nearest minute', () {
        final d = SessionDuration(
          elapsed: const Duration(minutes: 22, seconds: 20),
        );
        expect(d.arabicMinutesLabel, '٢٢ دقيقة');
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
  });
}
