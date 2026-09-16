// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ProcureFlow';

  @override
  String get appTagline => 'Smart Procurement. Less Waiting.';

  @override
  String goodMorning(String name) {
    return 'Good morning, $name 👋';
  }

  @override
  String goodAfternoon(String name) {
    return 'Good afternoon, $name 👋';
  }

  @override
  String goodEvening(String name) {
    return 'Good evening, $name 👋';
  }

  @override
  String get todaysProcurement => 'Today\'s Procurement';

  @override
  String get slotConfirmed => 'SLOT CONFIRMED';

  @override
  String get noActiveBooking => 'No active procurement booking';

  @override
  String get bookASlot => 'Book a Slot';

  @override
  String get trackQueue => 'TRACK QUEUE';

  @override
  String get bookSlot => 'Book Slot';

  @override
  String get myToken => 'My Token';

  @override
  String get procurement => 'Procurement';

  @override
  String get payment => 'Payment';

  @override
  String get notifications => 'Notifications';

  @override
  String get assistant => 'Assistant';

  @override
  String get home => 'Home';

  @override
  String get centres => 'Centres';

  @override
  String get queue => 'Queue';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get token => 'TOKEN';

  @override
  String farmersAhead(String count) {
    return '$count farmers ahead';
  }

  @override
  String get estimatedWaiting => 'Estimated waiting:';

  @override
  String minutes(String count) {
    return '$count minutes';
  }

  @override
  String get yourTurnApproaching => 'Your turn is approaching.';

  @override
  String get howCanIHelp => 'How can I help?';

  @override
  String get centreOpen => 'Open';

  @override
  String get centreClosed => 'Closed';

  @override
  String currentQueue(String count) {
    return 'Current queue: $count';
  }

  @override
  String availableSlots(String count) {
    return 'Available slots: $count';
  }

  @override
  String get viewSlots => 'VIEW SLOTS';

  @override
  String get selectCommodity => 'Select commodity';

  @override
  String get estimatedQuantity => 'Estimated quantity';

  @override
  String get quintal => 'quintal';

  @override
  String get selectCentre => 'Select procurement centre';

  @override
  String get selectDate => 'Select date';

  @override
  String get confirmBooking => 'Confirm Booking';

  @override
  String get bookingSuccessful => 'Booking successful';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get mobileNumber => 'Mobile number';

  @override
  String get enterOTP => 'Enter OTP';

  @override
  String get verifyOTP => 'Verify OTP';

  @override
  String get fullName => 'Full name';

  @override
  String get farmerId => 'Farmer ID';

  @override
  String get village => 'Village';

  @override
  String get district => 'District';

  @override
  String get preferredLanguage => 'Preferred language';

  @override
  String get primaryCommodity => 'Primary commodity';

  @override
  String get continueText => 'Continue';

  @override
  String get logout => 'Logout';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'Hindi';

  @override
  String get tamil => 'Tamil';

  @override
  String get waiting => 'WAITING';

  @override
  String get called => 'CALLED';

  @override
  String get processing => 'PROCESSING';

  @override
  String get completed => 'COMPLETED';

  @override
  String get paymentProcessing => 'Payment: PROCESSING';

  @override
  String get paymentCompleted => 'Payment: COMPLETED';

  @override
  String get todayQueue => 'Today\'s Queue';

  @override
  String get callNext => 'Call Next';

  @override
  String get markArrived => 'Mark Arrived';

  @override
  String get startProcessing => 'Start Processing';

  @override
  String get complete => 'Complete';

  @override
  String get noShow => 'No Show';

  @override
  String get offlineMessage =>
      'You are offline. Showing last updated information.';

  @override
  String lastUpdated(String time) {
    return 'Last updated $time';
  }

  @override
  String get demoMode => 'DEMO MODE';

  @override
  String get operatorDashboard => 'Operator Dashboard';

  @override
  String get waitingTimePrediction => 'Estimated waiting time';
}
