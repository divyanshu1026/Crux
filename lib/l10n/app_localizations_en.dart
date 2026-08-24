// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Crux';

  @override
  String get navToday => 'Today';

  @override
  String get navHistory => 'History';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navCoach => 'Coach';

  @override
  String get navProfile => 'Profile';

  @override
  String get todayTitle => 'Today';

  @override
  String get todayPlaceholder => 'Your plan for today shows up here.';

  @override
  String get historyTitle => 'History';

  @override
  String get historyPlaceholder => 'Every workout you finish is kept here.';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardPlaceholder => 'Your rank, streak, and trends live here.';

  @override
  String get coachTitle => 'Coach';

  @override
  String get coachPlaceholder =>
      'Ask your coach about training, form, or your plan.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profilePlaceholder => 'Your account, settings, and preferences.';

  @override
  String get galleryTitle => 'Design gallery';

  @override
  String get gallerySubtitle => 'Every token and component in one place.';

  @override
  String get actionStartWorkout => 'Start workout';

  @override
  String get actionLogSet => 'Log set';

  @override
  String get actionResumeWorkout => 'Resume workout';

  @override
  String get actionCancel => 'Cancel';
}
