// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'प्रोक्योरफ्लो';

  @override
  String get appTagline => 'स्मार्ट खरीद। कम प्रतीक्षा।';

  @override
  String goodMorning(String name) {
    return 'सुप्रभात, $name 👋';
  }

  @override
  String goodAfternoon(String name) {
    return 'नमस्ते, $name 👋';
  }

  @override
  String goodEvening(String name) {
    return 'शुभ संध्या, $name 👋';
  }

  @override
  String get todaysProcurement => 'आज की खरीद';

  @override
  String get slotConfirmed => 'स्लॉट पुष्टि';

  @override
  String get noActiveBooking => 'कोई सक्रिय बुकिंग नहीं';

  @override
  String get bookASlot => 'स्लॉट बुक करें';

  @override
  String get trackQueue => 'कतार देखें';

  @override
  String get bookSlot => 'स्लॉट बुक करें';

  @override
  String get myToken => 'मेरा टोकन';

  @override
  String get procurement => 'खरीद';

  @override
  String get payment => 'भुगतान';

  @override
  String get notifications => 'सूचनाएं';

  @override
  String get assistant => 'सहायक';

  @override
  String get home => 'होम';

  @override
  String get centres => 'केंद्र';

  @override
  String get queue => 'कतार';

  @override
  String get profile => 'प्रोफाइल';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get token => 'टोकन';

  @override
  String farmersAhead(String count) {
    return '$count किसान आगे';
  }

  @override
  String get estimatedWaiting => 'अनुमानित प्रतीक्षा:';

  @override
  String minutes(String count) {
    return '$count मिनट';
  }

  @override
  String get yourTurnApproaching => 'आपकी बारी आने वाली है।';

  @override
  String get howCanIHelp => 'मैं कैसे मदद कर सकता हूँ?';

  @override
  String get centreOpen => 'खुला';

  @override
  String get centreClosed => 'बंद';

  @override
  String currentQueue(String count) {
    return 'वर्तमान कतार: $count';
  }

  @override
  String availableSlots(String count) {
    return 'उपलब्ध स्लॉट: $count';
  }

  @override
  String get viewSlots => 'स्लॉट देखें';

  @override
  String get selectCommodity => 'फसल चुनें';

  @override
  String get estimatedQuantity => 'अनुमानित मात्रा';

  @override
  String get quintal => 'क्विंटल';

  @override
  String get selectCentre => 'केंद्र चुनें';

  @override
  String get selectDate => 'तारीख चुनें';

  @override
  String get confirmBooking => 'बुकिंग पुष्टि करें';

  @override
  String get bookingSuccessful => 'बुकिंग सफल';

  @override
  String get login => 'लॉगिन';

  @override
  String get register => 'पंजीकरण';

  @override
  String get mobileNumber => 'मोबाइल नंबर';

  @override
  String get enterOTP => 'OTP दर्ज करें';

  @override
  String get verifyOTP => 'OTP सत्यापित करें';

  @override
  String get fullName => 'पूरा नाम';

  @override
  String get farmerId => 'किसान आईडी';

  @override
  String get village => 'गाँव';

  @override
  String get district => 'जिला';

  @override
  String get preferredLanguage => 'पसंदीदा भाषा';

  @override
  String get primaryCommodity => 'मुख्य फसल';

  @override
  String get continueText => 'जारी रखें';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get language => 'भाषा';

  @override
  String get english => 'अंग्रेज़ी';

  @override
  String get hindi => 'हिंदी';

  @override
  String get tamil => 'तमिल';

  @override
  String get waiting => 'प्रतीक्षा में';

  @override
  String get called => 'बुलाया गया';

  @override
  String get processing => 'प्रक्रिया में';

  @override
  String get completed => 'पूर्ण';

  @override
  String get paymentProcessing => 'भुगतान: प्रक्रिया में';

  @override
  String get paymentCompleted => 'भुगतान: पूर्ण';

  @override
  String get todayQueue => 'आज की कतार';

  @override
  String get callNext => 'अगले को बुलाएं';

  @override
  String get markArrived => 'पहुंचा चिह्नित करें';

  @override
  String get startProcessing => 'प्रक्रिया शुरू करें';

  @override
  String get complete => 'पूर्ण करें';

  @override
  String get noShow => 'नहीं आया';

  @override
  String get offlineMessage =>
      'आप ऑफ़लाइन हैं। अंतिम अद्यतन जानकारी दिखाई जा रही है।';

  @override
  String lastUpdated(String time) {
    return 'अंतिम अद्यतन $time';
  }

  @override
  String get demoMode => 'डेमो मोड';

  @override
  String get operatorDashboard => 'ऑपरेटर डैशबोर्ड';

  @override
  String get waitingTimePrediction => 'अनुमानित प्रतीक्षा समय';

  @override
  String get booking => 'बुकिंग';

  @override
  String get navHome => 'होम';

  @override
  String get navCentres => 'केंद्र';

  @override
  String get navBooking => 'बुकिंग';

  @override
  String get navToken => 'टोकन';

  @override
  String get navQueue => 'कतार';

  @override
  String get navProcurement => 'खरीद';

  @override
  String get navPayment => 'भुगतान';

  @override
  String get navNotifications => 'सूचनाएं';

  @override
  String get navAssistant => 'सहायक';

  @override
  String get navProfile => 'प्रोफाइल';

  @override
  String get navSettings => 'सेटिंग्स';

  @override
  String get errorTitle => 'कुछ गलत हो गया';

  @override
  String get errorRetry => 'पुनः प्रयास';

  @override
  String get emptyTitle => 'कोई डेटा नहीं';

  @override
  String get loading => 'लोड हो रहा है...';

  @override
  String get arrived => 'पहुंच गए';

  @override
  String get cancelled => 'रद्द';

  @override
  String get bookingConfirmed => 'बुकिंग पुष्टि';

  @override
  String get paymentPending => 'भुगतान लंबित';
}
