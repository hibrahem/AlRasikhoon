/// Country configuration for phone number validation
class Country {
  final String code;
  final String dialCode;
  final String name;
  final String nameAr;
  final String flag;
  final int phoneLength;
  final String phonePattern;
  final String phoneHint;

  const Country({
    required this.code,
    required this.dialCode,
    required this.name,
    required this.nameAr,
    required this.flag,
    required this.phoneLength,
    required this.phonePattern,
    required this.phoneHint,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Country && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

class Countries {
  Countries._();

  static const Country egypt = Country(
    code: 'EG',
    dialCode: '+20',
    name: 'Egypt',
    nameAr: 'مصر',
    flag: '🇪🇬',
    phoneLength: 10,
    phonePattern: r'^1[0-9]{9}$',
    phoneHint: '1xxxxxxxxx',
  );

  static const Country saudiArabia = Country(
    code: 'SA',
    dialCode: '+966',
    name: 'Saudi Arabia',
    nameAr: 'السعودية',
    flag: '🇸🇦',
    phoneLength: 9,
    phonePattern: r'^5[0-9]{8}$',
    phoneHint: '5xxxxxxxx',
  );

  static const Country uae = Country(
    code: 'AE',
    dialCode: '+971',
    name: 'UAE',
    nameAr: 'الإمارات',
    flag: '🇦🇪',
    phoneLength: 9,
    phonePattern: r'^5[0-9]{8}$',
    phoneHint: '5xxxxxxxx',
  );

  static const Country kuwait = Country(
    code: 'KW',
    dialCode: '+965',
    name: 'Kuwait',
    nameAr: 'الكويت',
    flag: '🇰🇼',
    phoneLength: 8,
    phonePattern: r'^[5-9][0-9]{7}$',
    phoneHint: '5xxxxxxx',
  );

  static const Country qatar = Country(
    code: 'QA',
    dialCode: '+974',
    name: 'Qatar',
    nameAr: 'قطر',
    flag: '🇶🇦',
    phoneLength: 8,
    phonePattern: r'^[3-7][0-9]{7}$',
    phoneHint: '5xxxxxxx',
  );

  static const Country bahrain = Country(
    code: 'BH',
    dialCode: '+973',
    name: 'Bahrain',
    nameAr: 'البحرين',
    flag: '🇧🇭',
    phoneLength: 8,
    phonePattern: r'^[3][0-9]{7}$',
    phoneHint: '3xxxxxxx',
  );

  static const Country oman = Country(
    code: 'OM',
    dialCode: '+968',
    name: 'Oman',
    nameAr: 'عمان',
    flag: '🇴🇲',
    phoneLength: 8,
    phonePattern: r'^[79][0-9]{7}$',
    phoneHint: '9xxxxxxx',
  );

  static const Country jordan = Country(
    code: 'JO',
    dialCode: '+962',
    name: 'Jordan',
    nameAr: 'الأردن',
    flag: '🇯🇴',
    phoneLength: 9,
    phonePattern: r'^7[0-9]{8}$',
    phoneHint: '7xxxxxxxx',
  );

  /// All supported countries
  static const List<Country> all = [
    egypt,
    saudiArabia,
    uae,
    kuwait,
    qatar,
    bahrain,
    oman,
    jordan,
  ];

  /// Default country (Egypt)
  static const Country defaultCountry = egypt;

  /// Find country by code
  static Country? findByCode(String code) {
    try {
      return all.firstWhere((c) => c.code == code);
    } catch (_) {
      return null;
    }
  }

  /// Find country by dial code
  static Country? findByDialCode(String dialCode) {
    try {
      return all.firstWhere((c) => c.dialCode == dialCode);
    } catch (_) {
      return null;
    }
  }
}
