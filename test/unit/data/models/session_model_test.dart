import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:al_rasikhoon/data/models/session_model.dart';

/// The real level-1 rows, as `data/curriculum/sessions_level_1.json` carries
/// them. L1_J30_S30 is the hizb-59 سرد, S67 the juz-30 سرد, S68 its اختبار.
Map<String, dynamic> lessonJson({
  int sessionNumber = 1,
  int orderInLevel = 1,
  String kind = 'lesson',
}) => {
  'level_id': 1,
  'juz_number': 30,
  'session_number': sessionNumber,
  'order_in_level': orderInLevel,
  'kind': kind,
  'assessed_by': null,
  'unit_index': 1,
  'hizb_number': 59,
  'scope': null,
  'current_level_content': {
    'from_surah': 'النبأ',
    'from_verse': 1,
    'to_surah': 'النبأ',
    'to_verse': 11,
  },
  'recent_review_content': null,
  'distant_review_content': null,
};

final unitSardJson = <String, dynamic>{
  'level_id': 1,
  'juz_number': 30,
  'session_number': 30,
  'order_in_level': 30,
  'kind': 'sard',
  'assessed_by': 'teacher',
  'unit_index': 1,
  'hizb_number': 59,
  'scope': {
    'tier': 'unit',
    'label_ar': 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
    'hizb_number': 59,
    'juz_numbers': [30],
  },
  'current_level_content': null,
  'recent_review_content': {
    'from_surah': 'الطارق',
    'from_verse': 1,
    'to_surah': 'الطارق',
    'to_verse': 17,
  },
  'distant_review_content': null,
};

final juzSardJson = <String, dynamic>{
  'level_id': 1,
  'juz_number': 30,
  'session_number': 67,
  'order_in_level': 67,
  'kind': 'sard',
  'assessed_by': 'teacher',
  'unit_index': null,
  'hizb_number': null,
  'scope': {
    'tier': 'juz',
    'label_ar': 'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
    'hizb_number': null,
    'juz_numbers': [30],
  },
  'current_level_content': null,
  'recent_review_content': null,
  'distant_review_content': null,
};

final juzExamJson = <String, dynamic>{
  'level_id': 1,
  'juz_number': 30,
  'session_number': 68,
  'order_in_level': 68,
  'kind': 'exam',
  'assessed_by': 'supervisor',
  'unit_index': null,
  'hizb_number': null,
  'scope': {
    'tier': 'juz',
    'label_ar': 'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
    'hizb_number': null,
    'juz_numbers': [30],
  },
  'current_level_content': null,
  'recent_review_content': null,
  'distant_review_content': null,
};

final cumulativeSardJson = <String, dynamic>{
  'level_id': 1,
  'juz_number': 28,
  'session_number': 66,
  'order_in_level': 203,
  'kind': 'sard',
  'assessed_by': 'teacher',
  'unit_index': null,
  'hizb_number': null,
  'scope': {
    'tier': 'cumulative',
    'label_ar':
        'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
    'hizb_number': null,
    'juz_numbers': [28, 29, 30],
  },
  'current_level_content': null,
  'recent_review_content': null,
  'distant_review_content': null,
};

void main() {
  group('SessionKind', () {
    test('a kind is read from the curriculum data', () {
      expect(SessionKindX.fromString('lesson'), SessionKind.lesson);
      expect(SessionKindX.fromString('sard'), SessionKind.sard);
      expect(SessionKindX.fromString('exam'), SessionKind.exam);
    });

    test('an unknown kind is refused, never silently taught as a lesson', () {
      // Defaulting to a lesson is how a supervisor's اختبار disappears.
      expect(() => SessionKindX.fromString('garbage'), throwsArgumentError);
      expect(() => SessionKindX.fromString(''), throwsArgumentError);
    });

    test('kinds are named in Arabic', () {
      expect(SessionKind.lesson.nameAr, 'حلقة');
      expect(SessionKind.sard.nameAr, 'سرد');
      expect(SessionKind.exam.nameAr, 'اختبار');
    });
  });

  group('AssessmentTier', () {
    test('an assessment is scoped to a unit, a juz, or the level so far', () {
      expect(AssessmentTierX.fromString('unit'), AssessmentTier.unit);
      expect(AssessmentTierX.fromString('juz'), AssessmentTier.juz);
      expect(
        AssessmentTierX.fromString('cumulative'),
        AssessmentTier.cumulative,
      );
    });

    test('an unknown tier is refused', () {
      expect(() => AssessmentTierX.fromString('hizb'), throwsArgumentError);
    });
  });

  group('a session read from the curriculum', () {
    test('a lesson carries its content and no scope', () {
      final session = SessionModel.fromJson('L1_J30_S1', lessonJson());

      expect(session.isLesson, isTrue);
      expect(session.isAssessment, isFalse);
      expect(session.scope, isNull);
      expect(session.assessedBy, isNull);
      expect(session.currentLevelContent!.fromSurah, 'النبأ');
      expect(session.recentReviewContent, isNull);
    });

    test(
      'a review-only lesson has no current content and that is not an error',
      () {
        // Five legitimate lessons in the curriculum teach nothing new.
        final json = lessonJson()..['current_level_content'] = null;
        final session = SessionModel.fromJson('L1_J30_S40', json);

        expect(session.isLesson, isTrue);
        expect(session.currentLevelContent, isNull);
      },
    );

    test('a session numbered 35 that is a lesson stays a lesson', () {
      // The old model hard-coded 35 = سرد and 36 = اختبار. Session numbers now
      // run 1..N across a whole juz and say NOTHING about what a session is.
      final session = SessionModel.fromJson(
        'L1_J30_S35',
        lessonJson(sessionNumber: 35, orderInLevel: 35),
      );

      expect(session.kind, SessionKind.lesson);
      expect(session.isSard, isFalse);
      expect(session.isExam, isFalse);
    });

    test('the hizb سرد is a unit-tier سرد assessed by the teacher', () {
      final session = SessionModel.fromJson('L1_J30_S30', unitSardJson);

      expect(session.isSard, isTrue);
      expect(session.assessedBy, AssessedBy.teacher);
      expect(session.tier, AssessmentTier.unit);
      expect(session.scope!.hizbNumber, 59);
      expect(session.scope!.juzNumbers, [30]);
    });

    test('the juz سرد belongs to no hizb', () {
      final session = SessionModel.fromJson('L1_J30_S67', juzSardJson);

      expect(session.isSard, isTrue);
      expect(session.tier, AssessmentTier.juz);
      expect(session.hizbNumber, isNull);
      expect(session.scope!.hizbNumber, isNull);
      expect(session.unitIndex, isNull);
    });

    test('the juz اختبار is sat with the supervisor', () {
      final session = SessionModel.fromJson('L1_J30_S68', juzExamJson);

      expect(session.isExam, isTrue);
      expect(session.assessedBy, AssessedBy.supervisor);
      expect(session.tier, AssessmentTier.juz);
    });

    test('a cumulative سرد covers every juz taught so far in the level', () {
      final session = SessionModel.fromJson('L1_J28_S66', cumulativeSardJson);

      expect(session.tier, AssessmentTier.cumulative);
      expect(session.scope!.juzNumbers, [28, 29, 30]);
      expect(session.orderInLevel, 203);
    });
  });

  group('titleAr', () {
    test('an assessment is titled with the curriculum\'s own words', () {
      expect(
        SessionModel.fromJson('L1_J30_S67', juzSardJson).titleAr,
        'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
      );
      expect(
        SessionModel.fromJson('L1_J30_S68', juzExamJson).titleAr,
        'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
      );
      expect(
        SessionModel.fromJson('L1_J30_S30', unitSardJson).titleAr,
        'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
      );
      expect(
        SessionModel.fromJson('L1_J28_S66', cumulativeSardJson).titleAr,
        'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
      );
    });

    test('a lesson is titled by its session number and juz', () {
      final session = SessionModel.fromJson(
        'L1_J30_S5',
        lessonJson(sessionNumber: 5, orderInLevel: 5),
      );
      expect(session.titleAr, 'الحلقة 5 - الجزء 30');
    });
  });

  group('ordering', () {
    test('order_in_level runs continuously across the juz of the level', () {
      // Juz 30 ends at 68 and juz 29's first assessment lands at 100 — the
      // session number restarts per juz, the order in level does not.
      final juz30Exam = SessionModel.fromJson('L1_J30_S68', juzExamJson);
      final juz28Sard = SessionModel.fromJson('L1_J28_S66', cumulativeSardJson);

      expect(juz30Exam.orderInLevel, lessThan(juz28Sard.orderInLevel));
    });
  });

  group('persistence', () {
    test('a session round-trips through Firestore', () async {
      final fake = FakeFirebaseFirestore();
      final ref = fake.collection('sessions').doc('L1_J30_S67');
      await ref.set(juzSardJson);
      final DocumentSnapshot doc = await ref.get();

      final session = SessionModel.fromFirestore(doc);

      expect(session.id, 'L1_J30_S67');
      expect(session.kind, SessionKind.sard);
      expect(session.scope!.tier, AssessmentTier.juz);
      expect(session.titleAr, 'سرد الجزء رقم 30 كاملًا على المحفظ المتابع');

      final round = SessionModel.fromJson(session.id, session.toFirestore());
      expect(round.kind, session.kind);
      expect(round.orderInLevel, session.orderInLevel);
      expect(round.scope, session.scope);
      expect(round.assessedBy, AssessedBy.teacher);
    });

    test('sessions are equal by their document id', () {
      final a = SessionModel.fromJson('L1_J30_S67', juzSardJson);
      final b = SessionModel.fromJson('L1_J30_S67', juzExamJson);
      final c = SessionModel.fromJson('L1_J30_S68', juzExamJson);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('QuranContent', () {
    test('an absent content block reads back as absent, not as empty', () {
      expect(QuranContent.maybeFromJson(null), isNull);
    });

    test('rangeAr formats a same-surah range', () {
      const content = QuranContent(
        fromSurah: 'النبأ',
        fromVerse: 1,
        toSurah: 'النبأ',
        toVerse: 11,
      );
      expect(content.rangeAr, 'النبأ: 1 - 11');
    });

    test('rangeAr formats a cross-surah range', () {
      const content = QuranContent(
        fromSurah: 'الفلق',
        fromVerse: 1,
        toSurah: 'الناس',
        toVerse: 6,
      );
      expect(content.rangeAr, 'الفلق: 1 إلى الناس: 6');
    });
  });
}
