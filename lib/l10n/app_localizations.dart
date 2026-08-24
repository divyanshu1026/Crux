import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
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
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The application name.
  ///
  /// In en, this message translates to:
  /// **'Crux'**
  String get appName;

  /// Bottom navigation label for the Today tab.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// Bottom navigation label for the History tab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// Bottom navigation label for the Dashboard tab.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// Bottom navigation label for the Coach tab.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get navCoach;

  /// Bottom navigation label for the Profile tab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Title on the Today screen.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayTitle;

  /// Placeholder body on the Today screen.
  ///
  /// In en, this message translates to:
  /// **'Your plan for today shows up here.'**
  String get todayPlaceholder;

  /// Title on the History screen.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// Placeholder body on the History screen.
  ///
  /// In en, this message translates to:
  /// **'Every workout you finish is kept here.'**
  String get historyPlaceholder;

  /// Title on the Dashboard screen.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// Placeholder body on the Dashboard screen.
  ///
  /// In en, this message translates to:
  /// **'Your rank, streak, and trends live here.'**
  String get dashboardPlaceholder;

  /// Title on the Coach screen.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coachTitle;

  /// Placeholder body on the Coach screen.
  ///
  /// In en, this message translates to:
  /// **'Ask your coach about training, form, or your plan.'**
  String get coachPlaceholder;

  /// Title on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Placeholder body on the Profile screen.
  ///
  /// In en, this message translates to:
  /// **'Your account, settings, and preferences.'**
  String get profilePlaceholder;

  /// Title on the internal design gallery screen.
  ///
  /// In en, this message translates to:
  /// **'Design gallery'**
  String get galleryTitle;

  /// Subtitle on the design gallery screen.
  ///
  /// In en, this message translates to:
  /// **'Every token and component in one place.'**
  String get gallerySubtitle;

  /// Primary CTA to begin a workout.
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get actionStartWorkout;

  /// Primary CTA to log a single set.
  ///
  /// In en, this message translates to:
  /// **'Log set'**
  String get actionLogSet;

  /// CTA to resume an unfinished workout.
  ///
  /// In en, this message translates to:
  /// **'Resume workout'**
  String get actionResumeWorkout;

  /// Generic cancel action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
