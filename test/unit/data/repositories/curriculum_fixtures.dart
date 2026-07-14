import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Curriculum fixtures shaped exactly like `data/curriculum/*.json`.
///
/// The old fixtures WERE the old bug: they synthesized a session's kind from its
/// number (`session == 35 ? 'sard' : session == 36 ? 'exam' : 'regular'`) and
/// keyed everything on a hizb. The real curriculum numbers its sessions 1..N
/// across a whole juz (70 in juz 30 of level 1, 71 in juz 29, 69 in juz 28),
/// reads a session's kind from the source, and orders sessions by
/// `order_in_level`.
///
/// Level 1, juz 30 (as extracted):
/// - S1 the تلقين that opens hizb 59, S2..S30 its lessons,
/// - S31 the hizb-59 سرد, S32 its اختبار,
/// - S33 the تلقين that opens hizb 60, S34..S66 its lessons,
/// - S67/S68 the hizb-60 pair, S69 the juz-30 سرد, S70 its اختبار.
/// Level 1's juz run 30 → 29 → 28 (orders 1-70, 71-141, 142-210).
/// Level 10's juz run 1 → 2 → 3 — ASCENDING.
/// A تلقين opens every unit: the teacher reads the next lesson's passage to the
/// student, who memorizes and recites nothing.

/// Seeds one curriculum session, in the document shape the extractor writes.
Future<void> seedSession(
  FakeFirebaseFirestore firestore, {
  required int level,
  required int juz,
  required int session,
  required int order,
  String kind = 'lesson',
  String? assessedBy,
  int? unitIndex,
  int? hizb,
  String? tier,
  String? labelAr,
  List<int> juzNumbers = const [],
}) async {
  await firestore.collection('sessions').doc('L${level}_J${juz}_S$session').set(
    {
      'level_id': level,
      'juz_number': juz,
      'session_number': session,
      'order_in_level': order,
      'kind': kind,
      'assessed_by': assessedBy,
      'unit_index': unitIndex,
      'hizb_number': hizb,
      'scope': tier == null
          ? null
          : {
              'tier': tier,
              'label_ar': labelAr ?? '',
              'hizb_number': hizb,
              'juz_numbers': juzNumbers.isEmpty ? [juz] : juzNumbers,
            },
      'current_level_content': kind == 'lesson'
          ? {
              'from_surah': 'النبأ',
              'from_verse': 1,
              'to_surah': 'النبأ',
              'to_verse': 11,
            }
          : null,
      'recent_review_content': null,
      'distant_review_content': null,
    },
  );
}

/// Juz 30 of level 1: orders 1..70. Seeds a representative spine — the تلقين
/// that opens the hizb, the first two lessons, the hizb-59 unit pair, and the
/// juz-tier pair that closes the juz.
Future<void> seedLevelOneJuz30(FakeFirebaseFirestore firestore) async {
  // Every unit opens with a تلقين: the teacher reads the next lesson's passage
  // to the student.
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 1,
    order: 1,
    kind: 'talqeen',
    hizb: 59,
    unitIndex: 1,
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 2,
    order: 2,
    hizb: 59,
    unitIndex: 1,
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 3,
    order: 3,
    hizb: 59,
    unitIndex: 1,
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 31,
    order: 31,
    kind: 'sard',
    assessedBy: 'teacher',
    unitIndex: 1,
    hizb: 59,
    tier: 'unit',
    labelAr: 'سرد الحزب رقم 59 كاملًا على المحفظ المتابع',
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 32,
    order: 32,
    kind: 'exam',
    assessedBy: 'supervisor',
    unitIndex: 1,
    hizb: 59,
    tier: 'unit',
    labelAr: 'اختبار في الحزب رقم 59 كاملًا من قِبل إدارة الحلقات',
  );
  // The اختبار of hizb 59 is followed by the تلقين that opens hizb 60.
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 33,
    order: 33,
    kind: 'talqeen',
    hizb: 60,
    unitIndex: 2,
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 69,
    order: 69,
    kind: 'sard',
    assessedBy: 'teacher',
    tier: 'juz',
    labelAr: 'سرد الجزء رقم 30 كاملًا على المحفظ المتابع',
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 30,
    session: 70,
    order: 70,
    kind: 'exam',
    assessedBy: 'supervisor',
    tier: 'juz',
    labelAr: 'اختبار في الجزء رقم 30 كاملًا من قِبل إدارة الحلقات',
  );
}

/// Juz 29 of level 1: session numbers restart at 1, but the order runs on from
/// 71 — which is the whole point of `order_in_level`.
Future<void> seedLevelOneJuz29(FakeFirebaseFirestore firestore) async {
  await seedSession(
    firestore,
    level: 1,
    juz: 29,
    session: 1,
    order: 71,
    kind: 'talqeen',
    hizb: 57,
    unitIndex: 1,
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 29,
    session: 2,
    order: 72,
    hizb: 57,
    unitIndex: 1,
  );
}

/// The tail of level 1: its last session is the cumulative اختبار over juz
/// 28-29-30, at order 210.
Future<void> seedLevelOneTail(FakeFirebaseFirestore firestore) async {
  await seedSession(
    firestore,
    level: 1,
    juz: 28,
    session: 68,
    order: 209,
    kind: 'sard',
    assessedBy: 'teacher',
    tier: 'cumulative',
    labelAr:
        'سرد المستوى كاملًا الأجزاء رقم 28 ــ  29 ــ 30 على المحفظ المتابع',
    juzNumbers: [28, 29, 30],
  );
  await seedSession(
    firestore,
    level: 1,
    juz: 28,
    session: 69,
    order: 210,
    kind: 'exam',
    assessedBy: 'supervisor',
    tier: 'cumulative',
    labelAr:
        'اختبار في المستوى كاملًا  الأجزاء رقم 28 ــ  29 ــ 30 من قِبل إدارة الحلقات',
    juzNumbers: [28, 29, 30],
  );
}

/// The head of level 2: juz 27, session 1, order 1.
Future<void> seedLevelTwoHead(FakeFirebaseFirestore firestore) async {
  await seedSession(
    firestore,
    level: 2,
    juz: 27,
    session: 1,
    order: 1,
    kind: 'talqeen',
    hizb: 54,
    unitIndex: 1,
  );
}

/// Level 10 across its juz boundary. Level 10 teaches juz 1 → 2 → 3 ASCENDING:
/// the session after the last of juz 1 is the first of juz 2. Every arithmetic
/// rule ("the next juz is one lower") sent this student backwards.
Future<void> seedLevelTenJuz1To2(FakeFirebaseFirestore firestore) async {
  await seedSession(
    firestore,
    level: 10,
    juz: 1,
    session: 59,
    order: 59,
    kind: 'sard',
    assessedBy: 'teacher',
    tier: 'juz',
    labelAr: 'سرد الجزء رقم 1 كاملًا على المحفظ المتابع',
  );
  await seedSession(
    firestore,
    level: 10,
    juz: 1,
    session: 60,
    order: 60,
    kind: 'exam',
    assessedBy: 'supervisor',
    tier: 'juz',
    labelAr: 'اختبار في الجزء رقم 1 كاملًا من قِبل إدارة الحلقات',
  );
  await seedSession(firestore, level: 10, juz: 2, session: 1, order: 61);
  await seedSession(firestore, level: 10, juz: 2, session: 2, order: 62);
}

/// The very last session of the curriculum: level 10, juz 3, the cumulative
/// اختبار at order 180 (the level's session count).
Future<void> seedLevelTenTail(FakeFirebaseFirestore firestore) async {
  await seedSession(
    firestore,
    level: 10,
    juz: 3,
    session: 60,
    order: 180,
    kind: 'exam',
    assessedBy: 'supervisor',
    tier: 'cumulative',
    labelAr:
        'اختبار في المستوى كاملًا  الأجزاء رقم 1 ــ 2 ــ 3 من قِبل إدارة الحلقات',
    juzNumbers: [1, 2, 3],
  );
}

/// The levels catalog, as `levels.json` holds it: per-juz session counts and the
/// juz in TEACHING order.
Future<void> seedLevels(FakeFirebaseFirestore firestore) async {
  await firestore.collection('levels').doc('level_1').set({
    'id': 1,
    'name_ar': 'المستوى الأول',
    'name_en': 'Level 1',
    'order': 1,
    'juz_numbers': [30, 29, 28],
    'session_count': 210,
    'juz': [
      {
        'juz_number': 30,
        'session_count': 70,
        'hizb_numbers': [59, 60],
        'first_order_in_level': 1,
      },
      {
        'juz_number': 29,
        'session_count': 71,
        'hizb_numbers': [57, 58],
        'first_order_in_level': 71,
      },
      {
        'juz_number': 28,
        'session_count': 69,
        'hizb_numbers': [55, 56],
        'first_order_in_level': 142,
      },
    ],
  });
  await firestore.collection('levels').doc('level_2').set({
    'id': 2,
    'name_ar': 'المستوى الثاني',
    'name_en': 'Level 2',
    'order': 2,
    'juz_numbers': [27, 26, 25],
    'session_count': 154,
    'juz': [
      {
        'juz_number': 27,
        'session_count': 53,
        'hizb_numbers': [54, 53],
        'first_order_in_level': 1,
      },
    ],
  });
  await firestore.collection('levels').doc('level_10').set({
    'id': 10,
    'name_ar': 'المستوى العاشر',
    'name_en': 'Level 10',
    'order': 10,
    // ASCENDING — read from the data, never computed.
    'juz_numbers': [1, 2, 3],
    'session_count': 180,
    'juz': [
      {'juz_number': 1, 'session_count': 60, 'first_order_in_level': 1},
      {'juz_number': 2, 'session_count': 60, 'first_order_in_level': 61},
      {'juz_number': 3, 'session_count': 60, 'first_order_in_level': 121},
    ],
  });
}
