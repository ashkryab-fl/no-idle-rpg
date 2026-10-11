import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Pop culture nods: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Work, work.'**
  String get heroReturnLine01;

  /// Pop culture nods: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Off I go, then!'**
  String get heroReturnLine02;

  /// Pop culture nods: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'One does not simply clock out.'**
  String get heroReturnLine03;

  /// Pop culture nods: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'May the breaks be with me.'**
  String get heroReturnLine04;

  /// Pop culture nods: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'I\'ll be back... at work.'**
  String get heroReturnLine05;

  /// Pop culture nods: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'The grind is strong with this one.'**
  String get heroReturnLine06;

  /// Pop culture nods: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'I used to have weekends.'**
  String get heroReturnLine07;

  /// Pop culture nods: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'It\'s dangerous to work alone.'**
  String get heroReturnLine08;

  /// Pop culture nods: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Wake me when the quest ends.'**
  String get heroReturnLine09;

  /// Pop culture nods: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Achievement unlocked: overtime.'**
  String get heroReturnLine10;

  /// Weary humor: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'My soul called in sick.'**
  String get heroReturnLine11;

  /// Weary humor: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Another day, another goblin.'**
  String get heroReturnLine12;

  /// Weary humor: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Even my burnout is burned out.'**
  String get heroReturnLine13;

  /// Weary humor: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Paid in gold. Aged in dog years.'**
  String get heroReturnLine14;

  /// Weary humor: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Living the dream. Send help.'**
  String get heroReturnLine15;

  /// Weary humor: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'My pension is a healing potion.'**
  String get heroReturnLine16;

  /// Weary humor: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'All grind. No glory.'**
  String get heroReturnLine17;

  /// Weary humor: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'I\'m too tired to be dramatic.'**
  String get heroReturnLine18;

  /// Weary humor: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'My job title is \'Again.\''**
  String get heroReturnLine19;

  /// Weary humor: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'I miss being unconscious.'**
  String get heroReturnLine20;

  /// Bad excuses: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'That was a tactical nap.'**
  String get heroReturnLine21;

  /// Bad excuses: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'I was testing gravity.'**
  String get heroReturnLine22;

  /// Bad excuses: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'The sword needed a break.'**
  String get heroReturnLine23;

  /// Bad excuses: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'I was guarding this exact spot.'**
  String get heroReturnLine24;

  /// Bad excuses: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Just checking for floor traps.'**
  String get heroReturnLine25;

  /// Bad excuses: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'My eyes were buffering.'**
  String get heroReturnLine26;

  /// Bad excuses: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'I was charging my motivation.'**
  String get heroReturnLine27;

  /// Bad excuses: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'The goblins put me on hold.'**
  String get heroReturnLine28;

  /// Bad excuses: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'I dropped my work ethic.'**
  String get heroReturnLine29;

  /// Bad excuses: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'I was waiting for morale.'**
  String get heroReturnLine30;

  /// Fourth wall: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'You idle, I idle. Fair?'**
  String get heroReturnLine31;

  /// Fourth wall: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Nice break. Mine\'s unpaid.'**
  String get heroReturnLine32;

  /// Fourth wall: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Your mouse moved. There goes lunch.'**
  String get heroReturnLine33;

  /// Fourth wall: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'You get coffee. I get goblins.'**
  String get heroReturnLine34;

  /// Fourth wall: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Alt-Tab me out of this.'**
  String get heroReturnLine35;

  /// Fourth wall: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Could you click \'vacation\'?'**
  String get heroReturnLine36;

  /// Fourth wall: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'I\'m pixels, not a work ethic.'**
  String get heroReturnLine37;

  /// Fourth wall: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Close the laptop. Be a hero.'**
  String get heroReturnLine38;

  /// Fourth wall: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'You stretch. I get stretched.'**
  String get heroReturnLine39;

  /// Fourth wall: a short quip spoken by the heroine when she finishes resting and returns to work.
  ///
  /// In en, this message translates to:
  /// **'Same screen. Different suffering.'**
  String get heroReturnLine40;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
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
