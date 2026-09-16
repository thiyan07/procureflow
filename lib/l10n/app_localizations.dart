import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ta.dart';

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
    Locale('en'),
    Locale('hi'),
    Locale('ta'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ProcureFlow'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Smart Procurement. Less Waiting.'**
  String get appTagline;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name} 👋'**
  String goodMorning(String name);

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name} 👋'**
  String goodAfternoon(String name);

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name} 👋'**
  String goodEvening(String name);

  /// No description provided for @todaysProcurement.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Procurement'**
  String get todaysProcurement;

  /// No description provided for @slotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'SLOT CONFIRMED'**
  String get slotConfirmed;

  /// No description provided for @noActiveBooking.
  ///
  /// In en, this message translates to:
  /// **'No active procurement booking'**
  String get noActiveBooking;

  /// No description provided for @bookASlot.
  ///
  /// In en, this message translates to:
  /// **'Book a Slot'**
  String get bookASlot;

  /// No description provided for @trackQueue.
  ///
  /// In en, this message translates to:
  /// **'TRACK QUEUE'**
  String get trackQueue;

  /// No description provided for @bookSlot.
  ///
  /// In en, this message translates to:
  /// **'Book Slot'**
  String get bookSlot;

  /// No description provided for @myToken.
  ///
  /// In en, this message translates to:
  /// **'My Token'**
  String get myToken;

  /// No description provided for @procurement.
  ///
  /// In en, this message translates to:
  /// **'Procurement'**
  String get procurement;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @assistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistant;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @centres.
  ///
  /// In en, this message translates to:
  /// **'Centres'**
  String get centres;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @token.
  ///
  /// In en, this message translates to:
  /// **'TOKEN'**
  String get token;

  /// No description provided for @farmersAhead.
  ///
  /// In en, this message translates to:
  /// **'{count} farmers ahead'**
  String farmersAhead(String count);

  /// No description provided for @estimatedWaiting.
  ///
  /// In en, this message translates to:
  /// **'Estimated waiting:'**
  String get estimatedWaiting;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes'**
  String minutes(String count);

  /// No description provided for @yourTurnApproaching.
  ///
  /// In en, this message translates to:
  /// **'Your turn is approaching.'**
  String get yourTurnApproaching;

  /// No description provided for @howCanIHelp.
  ///
  /// In en, this message translates to:
  /// **'How can I help?'**
  String get howCanIHelp;

  /// No description provided for @centreOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get centreOpen;

  /// No description provided for @centreClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get centreClosed;

  /// No description provided for @currentQueue.
  ///
  /// In en, this message translates to:
  /// **'Current queue: {count}'**
  String currentQueue(String count);

  /// No description provided for @availableSlots.
  ///
  /// In en, this message translates to:
  /// **'Available slots: {count}'**
  String availableSlots(String count);

  /// No description provided for @viewSlots.
  ///
  /// In en, this message translates to:
  /// **'VIEW SLOTS'**
  String get viewSlots;

  /// No description provided for @selectCommodity.
  ///
  /// In en, this message translates to:
  /// **'Select commodity'**
  String get selectCommodity;

  /// No description provided for @estimatedQuantity.
  ///
  /// In en, this message translates to:
  /// **'Estimated quantity'**
  String get estimatedQuantity;

  /// No description provided for @quintal.
  ///
  /// In en, this message translates to:
  /// **'quintal'**
  String get quintal;

  /// No description provided for @selectCentre.
  ///
  /// In en, this message translates to:
  /// **'Select procurement centre'**
  String get selectCentre;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// No description provided for @confirmBooking.
  ///
  /// In en, this message translates to:
  /// **'Confirm Booking'**
  String get confirmBooking;

  /// No description provided for @bookingSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Booking successful'**
  String get bookingSuccessful;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get mobileNumber;

  /// No description provided for @enterOTP.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOTP;

  /// No description provided for @verifyOTP.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOTP;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @farmerId.
  ///
  /// In en, this message translates to:
  /// **'Farmer ID'**
  String get farmerId;

  /// No description provided for @village.
  ///
  /// In en, this message translates to:
  /// **'Village'**
  String get village;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @preferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred language'**
  String get preferredLanguage;

  /// No description provided for @primaryCommodity.
  ///
  /// In en, this message translates to:
  /// **'Primary commodity'**
  String get primaryCommodity;

  /// No description provided for @continueText.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @tamil.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get tamil;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'WAITING'**
  String get waiting;

  /// No description provided for @called.
  ///
  /// In en, this message translates to:
  /// **'CALLED'**
  String get called;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'PROCESSING'**
  String get processing;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get completed;

  /// No description provided for @paymentProcessing.
  ///
  /// In en, this message translates to:
  /// **'Payment: PROCESSING'**
  String get paymentProcessing;

  /// No description provided for @paymentCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment: COMPLETED'**
  String get paymentCompleted;

  /// No description provided for @todayQueue.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Queue'**
  String get todayQueue;

  /// No description provided for @callNext.
  ///
  /// In en, this message translates to:
  /// **'Call Next'**
  String get callNext;

  /// No description provided for @markArrived.
  ///
  /// In en, this message translates to:
  /// **'Mark Arrived'**
  String get markArrived;

  /// No description provided for @startProcessing.
  ///
  /// In en, this message translates to:
  /// **'Start Processing'**
  String get startProcessing;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @noShow.
  ///
  /// In en, this message translates to:
  /// **'No Show'**
  String get noShow;

  /// No description provided for @offlineMessage.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Showing last updated information.'**
  String get offlineMessage;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated {time}'**
  String lastUpdated(String time);

  /// No description provided for @demoMode.
  ///
  /// In en, this message translates to:
  /// **'DEMO MODE'**
  String get demoMode;

  /// No description provided for @operatorDashboard.
  ///
  /// In en, this message translates to:
  /// **'Operator Dashboard'**
  String get operatorDashboard;

  /// No description provided for @waitingTimePrediction.
  ///
  /// In en, this message translates to:
  /// **'Estimated waiting time'**
  String get waitingTimePrediction;
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
      <String>['en', 'hi', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
