// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Tamil (`ta`).
class AppLocalizationsTa extends AppLocalizations {
  AppLocalizationsTa([String locale = 'ta']) : super(locale);

  @override
  String get appTitle => 'ப்ரோக்யூர்ஃப்ளோ';

  @override
  String get appTagline => 'ஸ்மார்ட் கொள்முதல். குறைந்த காத்திருப்பு.';

  @override
  String goodMorning(String name) {
    return 'காலை வணக்கம், $name 👋';
  }

  @override
  String goodAfternoon(String name) {
    return 'மதிய வணக்கம், $name 👋';
  }

  @override
  String goodEvening(String name) {
    return 'மாலை வணக்கம், $name 👋';
  }

  @override
  String get todaysProcurement => 'இன்றைய கொள்முதல்';

  @override
  String get slotConfirmed => 'ஸ்லாட் உறுதி';

  @override
  String get noActiveBooking => 'செயலில் முன்பதிவு இல்லை';

  @override
  String get bookASlot => 'ஸ்லாட் முன்பதிவு செய்க';

  @override
  String get trackQueue => 'வரிசையைக் காண்க';

  @override
  String get bookSlot => 'ஸ்லாட் முன்பதிவு';

  @override
  String get myToken => 'எனது டோக்கன்';

  @override
  String get procurement => 'கொள்முதல்';

  @override
  String get payment => 'பணம்';

  @override
  String get notifications => 'அறிவிப்புகள்';

  @override
  String get assistant => 'உதவியாளர்';

  @override
  String get home => 'முகப்பு';

  @override
  String get centres => 'மையங்கள்';

  @override
  String get queue => 'வரிசை';

  @override
  String get profile => 'சுயவிவரம்';

  @override
  String get settings => 'அமைப்புகள்';

  @override
  String get token => 'டோக்கன்';

  @override
  String farmersAhead(String count) {
    return '$count விவசாயிகள் முன்னால்';
  }

  @override
  String get estimatedWaiting => 'மதிப்பிடப்பட்ட காத்திருப்பு:';

  @override
  String minutes(String count) {
    return '$count நிமிடங்கள்';
  }

  @override
  String get yourTurnApproaching => 'உங்கள் முறை நெருங்குகிறது.';

  @override
  String get howCanIHelp => 'நான் எப்படி உதவ முடியும்?';

  @override
  String get centreOpen => 'திறந்துள்ளது';

  @override
  String get centreClosed => 'மூடப்பட்டது';

  @override
  String currentQueue(String count) {
    return 'தற்போதைய வரிசை: $count';
  }

  @override
  String availableSlots(String count) {
    return 'கிடைக்கும் ஸ்லாட்கள்: $count';
  }

  @override
  String get viewSlots => 'ஸ்லாட்களைக் காண்க';

  @override
  String get selectCommodity => 'பயிரைத் தேர்ந்தெடுக்கவும்';

  @override
  String get estimatedQuantity => 'மதிப்பிடப்பட்ட அளவு';

  @override
  String get quintal => 'குவிண்டால்';

  @override
  String get selectCentre => 'மையத்தைத் தேர்ந்தெடுக்கவும்';

  @override
  String get selectDate => 'தேதியைத் தேர்ந்தெடுக்கவும்';

  @override
  String get confirmBooking => 'முன்பதிவை உறுதிப்படுத்தவும்';

  @override
  String get bookingSuccessful => 'முன்பதிவு வெற்றி';

  @override
  String get login => 'உள்நுழை';

  @override
  String get register => 'பதிவு';

  @override
  String get mobileNumber => 'கைபேசி எண்';

  @override
  String get enterOTP => 'OTP ஐ உள்ளிடவும்';

  @override
  String get verifyOTP => 'OTP ஐ சரிபார்க்கவும்';

  @override
  String get fullName => 'முழு பெயர்';

  @override
  String get farmerId => 'விவசாயி ஐடி';

  @override
  String get village => 'கிராமம்';

  @override
  String get district => 'மாவட்டம்';

  @override
  String get preferredLanguage => 'விருப்பமான மொழி';

  @override
  String get primaryCommodity => 'முக்கிய பயிர்';

  @override
  String get continueText => 'தொடரவும்';

  @override
  String get logout => 'வெளியேறு';

  @override
  String get language => 'மொழி';

  @override
  String get english => 'ஆங்கிலம்';

  @override
  String get hindi => 'இந்தி';

  @override
  String get tamil => 'தமிழ்';

  @override
  String get waiting => 'காத்திருப்பு';

  @override
  String get called => 'அழைக்கப்பட்டது';

  @override
  String get processing => 'செயலாக்கத்தில்';

  @override
  String get completed => 'முடிந்தது';

  @override
  String get paymentProcessing => 'பணம்: செயலாக்கத்தில்';

  @override
  String get paymentCompleted => 'பணம்: முடிந்தது';

  @override
  String get todayQueue => 'இன்றைய வரிசை';

  @override
  String get callNext => 'அடுத்தவரை அழைக்கவும்';

  @override
  String get markArrived => 'வந்ததாக குறிக்கவும்';

  @override
  String get startProcessing => 'செயலாக்கத்தைத் தொடங்கவும்';

  @override
  String get complete => 'முடிக்கவும்';

  @override
  String get noShow => 'வரவில்லை';

  @override
  String get offlineMessage =>
      'நீங்கள் ஆஃப்லைனில் உள்ளீர்கள். கடைசியாக புதுப்பிக்கப்பட்ட தகவல் காட்டப்படுகிறது.';

  @override
  String lastUpdated(String time) {
    return 'கடைசியாக புதுப்பிக்கப்பட்டது $time';
  }

  @override
  String get demoMode => 'டெமோ முறை';

  @override
  String get operatorDashboard => 'ஆபரேட்டர் டாஷ்போர்டு';

  @override
  String get waitingTimePrediction => 'மதிப்பிடப்பட்ட காத்திருப்பு நேரம்';
}
