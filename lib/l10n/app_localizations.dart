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

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'My boots just filed a request for a sit-down.'**
  String get heroBreakLine01;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Side quest: drink water. Yes, actual water.'**
  String get heroBreakLine02;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'We\'ve earned a break. I checked with my knees.'**
  String get heroBreakLine03;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Even goblins have lunch breaks. Allegedly.'**
  String get heroBreakLine04;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Your chair called. It wants some time apart.'**
  String get heroBreakLine05;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Let\'s stretch before we become ancient artifacts.'**
  String get heroBreakLine06;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'I\'m a heroine, not an overtime subscription.'**
  String get heroBreakLine07;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Save the kingdom after a sip of water?'**
  String get heroBreakLine08;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'My sword has better work-life balance. It gets sheathed.'**
  String get heroBreakLine09;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Your shoulders are trying to become earrings. Relax them.'**
  String get heroBreakLine10;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Permission to bravely sit on that rock?'**
  String get heroBreakLine11;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Overwork isn\'t a talent. I checked the skill tree.'**
  String get heroBreakLine12;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Look away from the screen. I\'ll admire this dirt.'**
  String get heroBreakLine13;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Hydration check! Coffee is not a personality trait.'**
  String get heroBreakLine14;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'My feet have started negotiating independently.'**
  String get heroBreakLine15;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Let\'s take five before five takes us.'**
  String get heroBreakLine16;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'You stretch your legs. I\'ll stop questioning mine.'**
  String get heroBreakLine17;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'The loot can wait. Your neck has a quest for you.'**
  String get heroBreakLine18;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'I could use a rest. You could use a refill.'**
  String get heroBreakLine19;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Blink twice if you need a break. Then take one.'**
  String get heroBreakLine20;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Even legendary weapons need downtime. So do wrists.'**
  String get heroBreakLine21;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'A short walk for you. A short sit for me. Deal?'**
  String get heroBreakLine22;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'That water bottle isn\'t decorative loot.'**
  String get heroBreakLine23;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'My stamina bar would like to speak to management.'**
  String get heroBreakLine24;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'The final boss is apparently our schedule.'**
  String get heroBreakLine25;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Unclench your jaw. We\'re not chewing the quest.'**
  String get heroBreakLine26;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'I vote for a snack break. My stomach seconds it.'**
  String get heroBreakLine27;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Rest is a buff. Why are we refusing free buffs?'**
  String get heroBreakLine28;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Some fresh air? This road is mostly recycled pixels.'**
  String get heroBreakLine29;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'My cape is carrying this team\'s work-life balance.'**
  String get heroBreakLine30;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Roll your shoulders. I\'ll roll my eyes at overtime.'**
  String get heroBreakLine31;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'We can be productive after being horizontal. Briefly.'**
  String get heroBreakLine32;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Drink some water before you unlock raisin mode.'**
  String get heroBreakLine33;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'This quest has no deadline. Your bladder might.'**
  String get heroBreakLine34;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'I\'d rescue a princess, but first I\'d rescue our lunch.'**
  String get heroBreakLine35;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Stand up slowly. Give your chair a dramatic farewell.'**
  String get heroBreakLine36;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Burnout is a terrible campfire. Let\'s not build one.'**
  String get heroBreakLine37;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'My break request has become a main quest.'**
  String get heroBreakLine38;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Go look at something far away. Not another tab.'**
  String get heroBreakLine39;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'We\'ve walked enough to qualify for a bench.'**
  String get heroBreakLine40;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Refill your glass. I\'ll refill my will to adventure.'**
  String get heroBreakLine41;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Stretch your fingers. They aren\'t permanent claws.'**
  String get heroBreakLine42;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'No achievement is worth becoming desk furniture.'**
  String get heroBreakLine43;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'A tiny break now beats a dramatic collapse later.'**
  String get heroBreakLine44;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'I\'d like my next encounter to be with a cushion.'**
  String get heroBreakLine45;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Check your posture. Mine comes with an animator.'**
  String get heroBreakLine46;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Time to pause the grind and uncrunch the spine.'**
  String get heroBreakLine47;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'The goblins won\'t miss us. That\'s a feature.'**
  String get heroBreakLine48;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Your next upgrade: water, a stretch, and a breather.'**
  String get heroBreakLine49;

  /// A playful break, hydration, or stretching reminder after forty minutes of uninterrupted adventure.
  ///
  /// In en, this message translates to:
  /// **'Let\'s rest. We can be suspiciously heroic afterward.'**
  String get heroBreakLine50;
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
