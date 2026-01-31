import '../constants/app_constants.dart';
import '../constants/countries.dart';

class Validators {
  Validators._();

  /// Validate email address
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال البريد الإلكتروني';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'البريد الإلكتروني غير صحيح';
    }

    return null;
  }

  /// Validate password (min 6 characters)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال كلمة المرور';
    }

    if (value.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }

    return null;
  }

  /// Validate confirm password
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'يرجى تأكيد كلمة المرور';
    }

    if (value != password) {
      return 'كلمة المرور غير متطابقة';
    }

    return null;
  }

  /// Validate phone number for a specific country
  static String? validatePhone(String? value, Country country) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال رقم الجوال';
    }

    // Remove any spaces or dashes
    final cleanNumber = value.replaceAll(RegExp(r'[\s-]'), '');

    // Check if it starts with 0 and remove it
    final phoneNumber = cleanNumber.startsWith('0')
        ? cleanNumber.substring(1)
        : cleanNumber;

    if (phoneNumber.length != country.phoneLength) {
      return 'رقم الجوال يجب أن يكون ${country.phoneLength} أرقام';
    }

    if (!RegExp(country.phonePattern).hasMatch(phoneNumber)) {
      return 'رقم الجوال غير صحيح';
    }

    return null;
  }

  /// Validate optional phone number
  static String? validateOptionalPhone(String? value, Country country) {
    if (value == null || value.isEmpty) {
      return null; // Phone is optional
    }
    return validatePhone(value, country);
  }

  /// Validate Saudi phone number (without country code) - Legacy support
  static String? validateSaudiPhone(String? value) {
    return validatePhone(value, Countries.saudiArabia);
  }

  /// Format phone number with country code
  static String formatPhoneWithCountryCode(String phone, {Country? country}) {
    final selectedCountry = country ?? Countries.defaultCountry;

    // Remove any spaces, dashes, or leading zeros
    var cleanNumber = phone.replaceAll(RegExp(r'[\s-]'), '');
    if (cleanNumber.startsWith('0')) {
      cleanNumber = cleanNumber.substring(1);
    }

    // Remove country dial code if already present (without +)
    final dialCodeWithoutPlus = selectedCountry.dialCode.substring(1);
    if (cleanNumber.startsWith(dialCodeWithoutPlus)) {
      cleanNumber = cleanNumber.substring(dialCodeWithoutPlus.length);
    }
    if (cleanNumber.startsWith(selectedCountry.dialCode)) {
      cleanNumber = cleanNumber.substring(selectedCountry.dialCode.length);
    }

    return '${selectedCountry.dialCode}$cleanNumber';
  }

  /// Validate OTP code
  static String? validateOtp(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال رمز التحقق';
    }

    if (value.length != AppConstants.otpLength) {
      return 'رمز التحقق يجب أن يكون ${AppConstants.otpLength} أرقام';
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'رمز التحقق يجب أن يحتوي على أرقام فقط';
    }

    return null;
  }

  /// Validate name (Arabic or English)
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال الاسم';
    }

    if (value.length < 2) {
      return 'الاسم يجب أن يكون حرفين على الأقل';
    }

    if (value.length > 100) {
      return 'الاسم طويل جداً';
    }

    return null;
  }

  /// Validate institute name
  static String? validateInstituteName(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال اسم المعهد';
    }

    if (value.length < 3) {
      return 'اسم المعهد يجب أن يكون 3 أحرف على الأقل';
    }

    if (value.length > 200) {
      return 'اسم المعهد طويل جداً';
    }

    return null;
  }

  /// Validate location
  static String? validateLocation(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال الموقع';
    }

    if (value.length < 2) {
      return 'الموقع يجب أن يكون حرفين على الأقل';
    }

    return null;
  }

  /// Validate error count (non-negative)
  static String? validateErrorCount(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال عدد الأخطاء';
    }

    final count = int.tryParse(value);
    if (count == null || count < 0) {
      return 'عدد الأخطاء يجب أن يكون رقماً صحيحاً';
    }

    return null;
  }

  /// Validate notes (optional, with max length)
  static String? validateNotes(String? value) {
    if (value != null && value.length > 500) {
      return 'الملاحظات طويلة جداً';
    }

    return null;
  }
}
