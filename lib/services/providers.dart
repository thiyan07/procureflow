import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories.dart';
import 'mock/mock_repositories.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => MockAuthRepository());
final farmerRepositoryProvider = Provider<FarmerRepository>((ref) => MockFarmerRepository());
final centreRepositoryProvider = Provider<CentreRepository>((ref) => MockCentreRepository());
final slotRepositoryProvider = Provider<SlotRepository>((ref) => MockSlotRepository());
final queueRepositoryProvider = Provider<QueueRepository>((ref) => MockQueueRepository());
final procurementRepositoryProvider = Provider<ProcurementRepository>((ref) => MockProcurementRepository());
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) => MockPaymentRepository());
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => MockNotificationRepository());
final aiRepositoryProvider = Provider<AIRepository>((ref) => MockAIRepository());

// Language provider
final languageCodeProvider = StateProvider<String>((ref) => 'en');

// Auth state
final authStateProvider = FutureProvider((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getCurrentUser();
});
