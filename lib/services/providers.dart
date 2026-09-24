import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories.dart';
import '../core/network/api_client.dart';
import '../core/storage/local_storage.dart';
import 'api/api_auth_repository.dart';
import 'api/api_farmer_repository.dart';
import 'api/api_centre_repository.dart';
import 'api/api_slot_repository.dart';
import 'api/api_queue_repository.dart';
import 'api/api_procurement_repository.dart';
import 'api/api_payment_repository.dart';
import 'api/api_notification_repository.dart';
import 'api/api_ai_repository.dart';

// Shared ApiClient
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// 100% real — no demo/mocks
final authRepositoryProvider = Provider<AuthRepository>((ref) => ApiAuthRepository(ref.watch(apiClientProvider)));
final farmerRepositoryProvider = Provider<FarmerRepository>((ref) => ApiFarmerRepository(ref.watch(apiClientProvider)));
final centreRepositoryProvider = Provider<CentreRepository>((ref) => ApiCentreRepository(ref.watch(apiClientProvider)));
final slotRepositoryProvider = Provider<SlotRepository>((ref) => ApiSlotRepository(ref.watch(apiClientProvider)));
final queueRepositoryProvider = Provider<QueueRepository>((ref) => ApiQueueRepository(ref.watch(apiClientProvider)));
final procurementRepositoryProvider = Provider<ProcurementRepository>((ref) => ApiProcurementRepository(ref.watch(apiClientProvider)));
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) => ApiPaymentRepository(ref.watch(apiClientProvider)));
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => ApiNotificationRepository(ref.watch(apiClientProvider)));
final aiRepositoryProvider = Provider<AIRepository>((ref) => ApiAiRepository(ref.watch(apiClientProvider)));

// Language provider — reads persisted value after LocalStorage.init()
final languageCodeProvider = StateProvider<String>((ref) {
  try {
    return LocalStorage.instance.languageCode;
  } catch (_) {
    return 'en';
  }
});

// Queue refresh trigger — increment after operator Call Next / transition to force dashboard/farmer refresh
final queueRefreshProvider = StateProvider<int>((ref) => 0);

// Auth state
final authStateProvider = FutureProvider((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getCurrentUser();
});
