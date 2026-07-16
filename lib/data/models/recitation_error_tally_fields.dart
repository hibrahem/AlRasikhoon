import '../../domain/assessment/assessment_evaluation.dart';

/// Firestore shape of a [RecitationErrorTally] list — one map per assessed
/// unit (a سرد face, an اختبار question), in recitation/sheet order.
///
/// Shared by [SardRecordModel] and [ExamRecordModel] so the two collections
/// cannot drift into different encodings of the same value object.
List<Map<String, int>> recitationTalliesToJson(
  List<RecitationErrorTally> tallies,
) => [
  for (final tally in tallies)
    {
      'tanbeehat': tally.tanbeehat,
      'talqeenat': tally.talqeenat,
      'tashkeel': tally.tashkeel,
      'tajweed': tally.tajweed,
    },
];

/// Absence is data: records written before assessments tracked per-unit error
/// types have no tally list at all, and read back as an empty list.
List<RecitationErrorTally> recitationTalliesFromJson(Object? json) {
  if (json == null) return const [];
  return [
    for (final entry in json as List)
      RecitationErrorTally.checked(
        tanbeehat: ((entry as Map)['tanbeehat'] as num?)?.toInt() ?? 0,
        talqeenat: (entry['talqeenat'] as num?)?.toInt() ?? 0,
        tashkeel: (entry['tashkeel'] as num?)?.toInt() ?? 0,
        tajweed: (entry['tajweed'] as num?)?.toInt() ?? 0,
      ),
  ];
}
