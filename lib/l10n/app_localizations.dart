import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'الراسخون'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get confirmPassword;

  /// No description provided for @signInWithGoogle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول بواسطة Google'**
  String get signInWithGoogle;

  /// No description provided for @forgotPassword.
  ///
  /// In ar, this message translates to:
  /// **'نسيت كلمة المرور؟'**
  String get forgotPassword;

  /// No description provided for @resetPassword.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تعيين كلمة المرور'**
  String get resetPassword;

  /// No description provided for @sendResetLink.
  ///
  /// In ar, this message translates to:
  /// **'إرسال رابط الاستعادة'**
  String get sendResetLink;

  /// No description provided for @resetLinkSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال رابط الاستعادة'**
  String get resetLinkSent;

  /// No description provided for @checkEmail.
  ///
  /// In ar, this message translates to:
  /// **'يرجى التحقق من بريدك الإلكتروني'**
  String get checkEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني غير صحيح'**
  String get invalidEmail;

  /// No description provided for @wrongPassword.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور غير صحيحة'**
  String get wrongPassword;

  /// No description provided for @setPassword.
  ///
  /// In ar, this message translates to:
  /// **'تعيين كلمة المرور'**
  String get setPassword;

  /// No description provided for @or.
  ///
  /// In ar, this message translates to:
  /// **'أو'**
  String get or;

  /// No description provided for @phoneNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الجوال'**
  String get phoneNumber;

  /// No description provided for @phoneOptional.
  ///
  /// In ar, this message translates to:
  /// **'رقم الجوال (اختياري)'**
  String get phoneOptional;

  /// No description provided for @guardianEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني لولي الأمر'**
  String get guardianEmail;

  /// No description provided for @guardianPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم ولي الأمر'**
  String get guardianPhone;

  /// No description provided for @accountNotFound.
  ///
  /// In ar, this message translates to:
  /// **'الحساب غير موجود'**
  String get accountNotFound;

  /// No description provided for @contactAdmin.
  ///
  /// In ar, this message translates to:
  /// **'يرجى التواصل مع المشرف لإنشاء حساب'**
  String get contactAdmin;

  /// No description provided for @dashboard.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get dashboard;

  /// No description provided for @students.
  ///
  /// In ar, this message translates to:
  /// **'الطلاب'**
  String get students;

  /// No description provided for @teachers.
  ///
  /// In ar, this message translates to:
  /// **'المعلمون'**
  String get teachers;

  /// No description provided for @institutes.
  ///
  /// In ar, this message translates to:
  /// **'المعاهد'**
  String get institutes;

  /// No description provided for @curriculum.
  ///
  /// In ar, this message translates to:
  /// **'المنهج'**
  String get curriculum;

  /// No description provided for @exams.
  ///
  /// In ar, this message translates to:
  /// **'الاختبارات'**
  String get exams;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @history.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get history;

  /// No description provided for @practice.
  ///
  /// In ar, this message translates to:
  /// **'التدريب'**
  String get practice;

  /// No description provided for @superAdmin.
  ///
  /// In ar, this message translates to:
  /// **'مدير النظام'**
  String get superAdmin;

  /// No description provided for @supervisor.
  ///
  /// In ar, this message translates to:
  /// **'المشرف'**
  String get supervisor;

  /// No description provided for @teacher.
  ///
  /// In ar, this message translates to:
  /// **'المعلم'**
  String get teacher;

  /// No description provided for @student.
  ///
  /// In ar, this message translates to:
  /// **'الطالب'**
  String get student;

  /// No description provided for @guardian.
  ///
  /// In ar, this message translates to:
  /// **'ولي الأمر'**
  String get guardian;

  /// No description provided for @addStudent.
  ///
  /// In ar, this message translates to:
  /// **'إضافة طالب'**
  String get addStudent;

  /// No description provided for @addTeacher.
  ///
  /// In ar, this message translates to:
  /// **'إضافة معلم'**
  String get addTeacher;

  /// No description provided for @addInstitute.
  ///
  /// In ar, this message translates to:
  /// **'إضافة معهد'**
  String get addInstitute;

  /// No description provided for @studentName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الطالب'**
  String get studentName;

  /// No description provided for @teacherName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المعلم'**
  String get teacherName;

  /// No description provided for @instituteName.
  ///
  /// In ar, this message translates to:
  /// **'اسم المعهد'**
  String get instituteName;

  /// No description provided for @location.
  ///
  /// In ar, this message translates to:
  /// **'الموقع'**
  String get location;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @currentLevel.
  ///
  /// In ar, this message translates to:
  /// **'المستوى الحالي'**
  String get currentLevel;

  /// No description provided for @currentJuz.
  ///
  /// In ar, this message translates to:
  /// **'الجزء الحالي'**
  String get currentJuz;

  /// No description provided for @currentHizb.
  ///
  /// In ar, this message translates to:
  /// **'الحزب الحالي'**
  String get currentHizb;

  /// No description provided for @currentSession.
  ///
  /// In ar, this message translates to:
  /// **'الحلقة الحالية'**
  String get currentSession;

  /// No description provided for @completedLevels.
  ///
  /// In ar, this message translates to:
  /// **'المستويات المكتملة'**
  String get completedLevels;

  /// No description provided for @progress.
  ///
  /// In ar, this message translates to:
  /// **'التقدم'**
  String get progress;

  /// No description provided for @startSession.
  ///
  /// In ar, this message translates to:
  /// **'بدء الحلقة'**
  String get startSession;

  /// No description provided for @endSession.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الحلقة'**
  String get endSession;

  /// No description provided for @sessionSummary.
  ///
  /// In ar, this message translates to:
  /// **'ملخص الحلقة'**
  String get sessionSummary;

  /// No description provided for @recitation.
  ///
  /// In ar, this message translates to:
  /// **'التسميع'**
  String get recitation;

  /// No description provided for @newMemorization.
  ///
  /// In ar, this message translates to:
  /// **'الحفظ الجديد'**
  String get newMemorization;

  /// No description provided for @review.
  ///
  /// In ar, this message translates to:
  /// **'المراجعة'**
  String get review;

  /// No description provided for @recentReview.
  ///
  /// In ar, this message translates to:
  /// **'المراجعة القريبة'**
  String get recentReview;

  /// No description provided for @distantReview.
  ///
  /// In ar, this message translates to:
  /// **'المراجعة البعيدة'**
  String get distantReview;

  /// No description provided for @errors.
  ///
  /// In ar, this message translates to:
  /// **'الأخطاء'**
  String get errors;

  /// No description provided for @errorCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد الأخطاء'**
  String get errorCount;

  /// No description provided for @addError.
  ///
  /// In ar, this message translates to:
  /// **'إضافة خطأ'**
  String get addError;

  /// No description provided for @undoError.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get undoError;

  /// No description provided for @grade.
  ///
  /// In ar, this message translates to:
  /// **'التقدير'**
  String get grade;

  /// No description provided for @passed.
  ///
  /// In ar, this message translates to:
  /// **'ناجح'**
  String get passed;

  /// No description provided for @failed.
  ///
  /// In ar, this message translates to:
  /// **'راسب'**
  String get failed;

  /// No description provided for @attempt.
  ///
  /// In ar, this message translates to:
  /// **'المحاولة'**
  String get attempt;

  /// No description provided for @repetitions.
  ///
  /// In ar, this message translates to:
  /// **'التكرارات'**
  String get repetitions;

  /// No description provided for @notes.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get notes;

  /// No description provided for @gradeRasikh.
  ///
  /// In ar, this message translates to:
  /// **'راسخ'**
  String get gradeRasikh;

  /// No description provided for @gradeMutqin.
  ///
  /// In ar, this message translates to:
  /// **'متقن'**
  String get gradeMutqin;

  /// No description provided for @gradeHafiz.
  ///
  /// In ar, this message translates to:
  /// **'حافظ'**
  String get gradeHafiz;

  /// No description provided for @gradeMujtahid.
  ///
  /// In ar, this message translates to:
  /// **'مجتهد'**
  String get gradeMujtahid;

  /// No description provided for @gradeMuhib.
  ///
  /// In ar, this message translates to:
  /// **'محب'**
  String get gradeMuhib;

  /// No description provided for @sard.
  ///
  /// In ar, this message translates to:
  /// **'السرد'**
  String get sard;

  /// No description provided for @sardSession.
  ///
  /// In ar, this message translates to:
  /// **'جلسة السرد'**
  String get sardSession;

  /// No description provided for @exam.
  ///
  /// In ar, this message translates to:
  /// **'الاختبار'**
  String get exam;

  /// No description provided for @examQueue.
  ///
  /// In ar, this message translates to:
  /// **'قائمة الاختبارات'**
  String get examQueue;

  /// No description provided for @conductExam.
  ///
  /// In ar, this message translates to:
  /// **'إجراء الاختبار'**
  String get conductExam;

  /// No description provided for @examResult.
  ///
  /// In ar, this message translates to:
  /// **'نتيجة الاختبار'**
  String get examResult;

  /// No description provided for @fromSurah.
  ///
  /// In ar, this message translates to:
  /// **'من سورة'**
  String get fromSurah;

  /// No description provided for @toSurah.
  ///
  /// In ar, this message translates to:
  /// **'إلى سورة'**
  String get toSurah;

  /// No description provided for @fromVerse.
  ///
  /// In ar, this message translates to:
  /// **'من آية'**
  String get fromVerse;

  /// No description provided for @toVerse.
  ///
  /// In ar, this message translates to:
  /// **'إلى آية'**
  String get toVerse;

  /// No description provided for @level.
  ///
  /// In ar, this message translates to:
  /// **'المستوى'**
  String get level;

  /// No description provided for @juz.
  ///
  /// In ar, this message translates to:
  /// **'الجزء'**
  String get juz;

  /// No description provided for @hizb.
  ///
  /// In ar, this message translates to:
  /// **'الحزب'**
  String get hizb;

  /// No description provided for @session.
  ///
  /// In ar, this message translates to:
  /// **'الحلقة'**
  String get session;

  /// No description provided for @noStudents.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد طلاب'**
  String get noStudents;

  /// No description provided for @noTeachers.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد معلمون'**
  String get noTeachers;

  /// No description provided for @noInstitutes.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد معاهد'**
  String get noInstitutes;

  /// No description provided for @noExams.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اختبارات'**
  String get noExams;

  /// No description provided for @noHistory.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد سجل'**
  String get noHistory;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحميل...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @noConnection.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت'**
  String get noConnection;

  /// No description provided for @assignToInstitute.
  ///
  /// In ar, this message translates to:
  /// **'تعيين للمعهد'**
  String get assignToInstitute;

  /// No description provided for @assignedTeachers.
  ///
  /// In ar, this message translates to:
  /// **'المعلمون المعينون'**
  String get assignedTeachers;

  /// No description provided for @assignedSupervisors.
  ///
  /// In ar, this message translates to:
  /// **'المشرفون المعينون'**
  String get assignedSupervisors;

  /// No description provided for @totalSessions.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الحلقات'**
  String get totalSessions;

  /// No description provided for @completedSessions.
  ///
  /// In ar, this message translates to:
  /// **'الحلقات المكتملة'**
  String get completedSessions;

  /// No description provided for @remainingSessions.
  ///
  /// In ar, this message translates to:
  /// **'الحلقات المتبقية'**
  String get remainingSessions;

  /// No description provided for @homePractice.
  ///
  /// In ar, this message translates to:
  /// **'التدريب المنزلي'**
  String get homePractice;

  /// No description provided for @markAsComplete.
  ///
  /// In ar, this message translates to:
  /// **'تم الإكمال'**
  String get markAsComplete;

  /// No description provided for @practiceHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل التدريب'**
  String get practiceHistory;

  /// No description provided for @selectStudent.
  ///
  /// In ar, this message translates to:
  /// **'اختر الطالب'**
  String get selectStudent;

  /// No description provided for @selectInstitute.
  ///
  /// In ar, this message translates to:
  /// **'اختر المعهد'**
  String get selectInstitute;

  /// No description provided for @selectLevel.
  ///
  /// In ar, this message translates to:
  /// **'اختر المستوى'**
  String get selectLevel;

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get yesterday;

  /// No description provided for @thisWeek.
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر'**
  String get thisMonth;

  /// No description provided for @statistics.
  ///
  /// In ar, this message translates to:
  /// **'الإحصائيات'**
  String get statistics;

  /// No description provided for @totalStudents.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الطلاب'**
  String get totalStudents;

  /// No description provided for @activeStudents.
  ///
  /// In ar, this message translates to:
  /// **'الطلاب النشطون'**
  String get activeStudents;

  /// No description provided for @passRate.
  ///
  /// In ar, this message translates to:
  /// **'نسبة النجاح'**
  String get passRate;

  /// No description provided for @averageGrade.
  ///
  /// In ar, this message translates to:
  /// **'متوسط التقدير'**
  String get averageGrade;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
