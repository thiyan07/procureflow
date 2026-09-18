import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories.dart';
import 'mock/mock_repositories.dart';
import '../core/network/api_client.dart';
import '../core/config/demo_config.dart';
import 'api/api_auth_repository.dart';
import 'api/api_farmer_repository.dart';
import 'api/api_centre_repository.dart';
import 'api/api_slot_repository.dart';
import 'api/api_queue_repository.dart';
import 'api/api_procurement_repository.dart';
import 'api/api_payment_repository.dart';
import 'api/api_notification_repository.dart';

// Shared ApiClient
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

bool get _useMock => DemoConfig.useMockBackend;

final authRepositoryProvider = Provider<AuthRepository>((ref) => _useMock ? MockAuthRepository() : ApiAuthRepository(ref.watch(apiClientProvider)));
final farmerRepositoryProvider = Provider<FarmerRepository>((ref) => _useMock ? MockFarmerRepository() : ApiFarmerRepository(ref.watch(apiClientProvider)));
final centreRepositoryProvider = Provider<CentreRepository>((ref) => _useMock ? MockCentreRepository() : ApiCentreRepository(ref.watch(apiClientProvider)));
final slotRepositoryProvider = Provider<SlotRepository>((ref) => _useMock ? MockSlotRepository() : ApiSlotRepository(ref.watch(apiClientProvider)));
final queueRepositoryProvider = Provider<QueueRepository>((ref) => _useMock ? MockQueueRepository() : ApiQueueRepository(ref.watch(apiClientProvider)));
final procurementRepositoryProvider = Provider<ProcurementRepository>((ref) => _useMock ? MockProcurementRepository() : ApiProcurementRepository(ref.watch(apiClientProvider)));
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) => _useMock ? MockPaymentRepository() : ApiPaymentRepository(ref.watch(apiClientProvider)));
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => _useMock ? MockNotificationRepository() : ApiNotificationRepository(ref.watch(apiClientProvider)));
final aiRepositoryProvider = Provider<AIRepository>((ref) => MockAIRepository());

// Language provider
final languageCodeProvider = StateProvider<String>((ref) => 'en');

// Auth state
final authStateProvider = FutureProvider((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getCurrentUser();
});
