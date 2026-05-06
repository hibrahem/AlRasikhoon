import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';

void main() {
  group('SessionType', () {
    group('value', () {
      test('regular returns regular', () {
        expect(SessionType.regular.value, 'regular');
      });

      test('sard returns sard', () {
        expect(SessionType.sard.value, 'sard');
      });

      test('exam returns exam', () {
        expect(SessionType.exam.value, 'exam');
      });
    });

    group('nameAr', () {
      test('regular returns حلقة عادية', () {
        expect(SessionType.regular.nameAr, 'حلقة عادية');
      });

      test('sard returns سرد', () {
        expect(SessionType.sard.nameAr, 'سرد');
      });

      test('exam returns اختبار', () {
        expect(SessionType.exam.nameAr, 'اختبار');
      });
    });

    group('nameEn', () {
      test('regular returns Regular Session', () {
        expect(SessionType.regular.nameEn, 'Regular Session');
      });

      test('sard returns Sard', () {
        expect(SessionType.sard.nameEn, 'Sard');
      });

      test('exam returns Exam', () {
        expect(SessionType.exam.nameEn, 'Exam');
      });
    });

    group('fromString', () {
      test('"sard" returns SessionType.sard', () {
        expect(SessionTypeExtension.fromString('sard'), SessionType.sard);
      });

      test('"exam" returns SessionType.exam', () {
        expect(SessionTypeExtension.fromString('exam'), SessionType.exam);
      });

      test('"regular" returns SessionType.regular', () {
        expect(SessionTypeExtension.fromString('regular'), SessionType.regular);
      });

      test('unknown string defaults to SessionType.regular', () {
        expect(SessionTypeExtension.fromString('garbage'), SessionType.regular);
      });

      test('empty string defaults to SessionType.regular', () {
        expect(SessionTypeExtension.fromString(''), SessionType.regular);
      });
    });
  });

  group('QuranContent', () {
    test('isEmpty true when fromSurah is empty', () {
      const content = QuranContent(
        fromSurah: '',
        fromVerse: 0,
        toSurah: '',
        toVerse: 0,
      );
      expect(content.isEmpty, isTrue);
      expect(content.rangeAr, '');
      expect(content.rangeEn, '');
    });

    test('isEmpty false when fromSurah has content', () {
      const content = QuranContent(
        fromSurah: 'الفاتحة',
        fromVerse: 1,
        toSurah: 'الفاتحة',
        toVerse: 7,
      );
      expect(content.isEmpty, isFalse);
    });

    test('rangeAr formats single-verse range', () {
      const content = QuranContent(
        fromSurah: 'الفاتحة',
        fromVerse: 1,
        toSurah: 'الفاتحة',
        toVerse: 1,
      );
      expect(content.rangeAr, 'الفاتحة: 1');
    });

    test('rangeAr formats same-surah verse range', () {
      const content = QuranContent(
        fromSurah: 'الفاتحة',
        fromVerse: 1,
        toSurah: 'الفاتحة',
        toVerse: 7,
      );
      expect(content.rangeAr, 'الفاتحة: 1 - 7');
    });

    test('rangeAr formats cross-surah range', () {
      const content = QuranContent(
        fromSurah: 'البقرة',
        fromVerse: 1,
        toSurah: 'آل عمران',
        toVerse: 10,
      );
      expect(content.rangeAr, 'البقرة: 1 إلى آل عمران: 10');
    });

    test('rangeEn formats cross-surah range', () {
      const content = QuranContent(
        fromSurah: 'Al-Baqarah',
        fromVerse: 1,
        toSurah: 'Al-Imran',
        toVerse: 10,
      );
      expect(content.rangeEn, 'Al-Baqarah: 1 to Al-Imran: 10');
    });

    test('fromJson handles null map by returning empty content', () {
      final content = QuranContent.fromJson(null);
      expect(content.isEmpty, isTrue);
      expect(content.fromVerse, 0);
      expect(content.toVerse, 0);
    });

    test('fromJson handles missing fields with defaults', () {
      final content = QuranContent.fromJson(<String, dynamic>{});
      expect(content.fromSurah, '');
      expect(content.fromVerse, 0);
      expect(content.toSurah, '');
      expect(content.toVerse, 0);
    });

    test('toJson round-trips through fromJson', () {
      const original = QuranContent(
        fromSurah: 'البقرة',
        fromVerse: 1,
        toSurah: 'البقرة',
        toVerse: 5,
      );
      final round = QuranContent.fromJson(original.toJson());
      expect(round.fromSurah, original.fromSurah);
      expect(round.fromVerse, original.fromVerse);
      expect(round.toSurah, original.toSurah);
      expect(round.toVerse, original.toVerse);
    });
  });

  group('SessionModel', () {
    SessionModel buildSession({
      String id = 'L1_J30_H59_S1',
      int sessionNumber = 1,
      int hizbNumber = 59,
      SessionType type = SessionType.regular,
    }) {
      return SessionModel(
        id: id,
        sessionNumber: sessionNumber,
        levelId: 1,
        juzNumber: 30,
        hizbNumber: hizbNumber,
        sessionType: type,
        currentLevelContent: const QuranContent(
          fromSurah: 'الناس',
          fromVerse: 1,
          toSurah: 'الفلق',
          toVerse: 5,
        ),
        recentReviewContent: const QuranContent(
          fromSurah: '',
          fromVerse: 0,
          toSurah: '',
          toVerse: 0,
        ),
        distantReviewContent: const QuranContent(
          fromSurah: '',
          fromVerse: 0,
          toSurah: '',
          toVerse: 0,
        ),
      );
    }

    test('isSard true only for sard type', () {
      expect(buildSession(type: SessionType.sard).isSard, isTrue);
      expect(buildSession(type: SessionType.exam).isSard, isFalse);
      expect(buildSession(type: SessionType.regular).isSard, isFalse);
    });

    test('isExam true only for exam type', () {
      expect(buildSession(type: SessionType.exam).isExam, isTrue);
      expect(buildSession(type: SessionType.sard).isExam, isFalse);
      expect(buildSession(type: SessionType.regular).isExam, isFalse);
    });

    test('isRegular true only for regular type', () {
      expect(buildSession(type: SessionType.regular).isRegular, isTrue);
      expect(buildSession(type: SessionType.sard).isRegular, isFalse);
      expect(buildSession(type: SessionType.exam).isRegular, isFalse);
    });

    test('titleAr for sard session includes hizb', () {
      final s = buildSession(type: SessionType.sard, hizbNumber: 59);
      expect(s.titleAr, 'سرد الحزب 59');
    });

    test('titleAr for exam session includes hizb', () {
      final s = buildSession(type: SessionType.exam, hizbNumber: 59);
      expect(s.titleAr, 'اختبار الحزب 59');
    });

    test('titleAr for regular session includes session number and hizb', () {
      final s = buildSession(sessionNumber: 5, hizbNumber: 59);
      expect(s.titleAr, 'الحلقة 5 - الحزب 59');
    });

    test('titleEn for sard session includes hizb', () {
      final s = buildSession(type: SessionType.sard, hizbNumber: 59);
      expect(s.titleEn, 'Sard - Hizb 59');
    });

    test('titleEn for exam session includes hizb', () {
      final s = buildSession(type: SessionType.exam, hizbNumber: 59);
      expect(s.titleEn, 'Exam - Hizb 59');
    });

    test('equality based on id only, not other fields', () {
      final a = buildSession(id: 'X', sessionNumber: 1);
      final b = buildSession(id: 'X', sessionNumber: 99);
      final c = buildSession(id: 'Y', sessionNumber: 1);
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });

    test('toFirestore + fromJson round-trip preserves all fields', () {
      final original = buildSession(
        id: 'L1_J30_H59_S35',
        sessionNumber: 35,
        type: SessionType.sard,
      );
      final json = original.toFirestore();
      final round = SessionModel.fromJson(original.id, json);
      expect(round.id, original.id);
      expect(round.sessionNumber, original.sessionNumber);
      expect(round.levelId, original.levelId);
      expect(round.juzNumber, original.juzNumber);
      expect(round.hizbNumber, original.hizbNumber);
      expect(round.sessionType, original.sessionType);
      expect(
        round.currentLevelContent.fromSurah,
        original.currentLevelContent.fromSurah,
      );
    });

    test('fromJson defaults missing fields to safe values', () {
      final s = SessionModel.fromJson('id_only', <String, dynamic>{});
      expect(s.sessionNumber, 0);
      expect(s.levelId, 1);
      expect(s.juzNumber, 30);
      expect(s.hizbNumber, 59);
      expect(s.sessionType, SessionType.regular);
      expect(s.currentLevelContent.isEmpty, isTrue);
    });

    test('fromFirestore deserializes from a real DocumentSnapshot', () async {
      final fake = FakeFirebaseFirestore();
      final ref = fake.collection('sessions').doc('L1_J30_H59_S1');
      await ref.set({
        'session_number': 1,
        'level_id': 1,
        'juz_number': 30,
        'hizb_number': 59,
        'session_type': 'regular',
        'current_level_content': {
          'from_surah': 'الناس',
          'from_verse': 1,
          'to_surah': 'الفلق',
          'to_verse': 5,
        },
        'recent_review_content': {
          'from_surah': '',
          'from_verse': 0,
          'to_surah': '',
          'to_verse': 0,
        },
        'distant_review_content': {
          'from_surah': '',
          'from_verse': 0,
          'to_surah': '',
          'to_verse': 0,
        },
      });
      final DocumentSnapshot doc = await ref.get();

      final session = SessionModel.fromFirestore(doc);

      expect(session.id, 'L1_J30_H59_S1');
      expect(session.sessionNumber, 1);
      expect(session.sessionType, SessionType.regular);
      expect(session.currentLevelContent.fromSurah, 'الناس');
    });
  });
}
