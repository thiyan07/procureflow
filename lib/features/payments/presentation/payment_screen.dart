import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';
import '../../../models/booking.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_utils.dart';

class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(_activeBookingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Status')),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,s) => ErrorState(message: e.toString()),
        data: (booking){
          if (booking==null) return const EmptyState(title: 'No payment', subtitle: 'Complete procurement first', icon: Icons.payments_outlined);
          return FutureBuilder(
            future: ref.read(paymentRepositoryProvider).getPayment(booking.id),
            builder: (context, snap){
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final p = snap.data!;
              final isCompleted = p.status==PaymentStatus.completed;
              return ListView(padding: const EdgeInsets.all(16), children: [
                AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                  Row(children:[
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.payments, color: Color(0xFF2E7D32))),
                    const SizedBox(width:12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                      Text(p.commodity, style: const TextStyle(fontWeight: FontWeight.w700, fontSize:16)),
                      Text('${p.quantityQuintal} quintal • ₹${p.ratePerQuintal.toStringAsFixed(0)}/quintal', style: const TextStyle(color: Colors.black54, fontSize:12)),
                    ])),
                    StatusChip(label: p.status.name.toUpperCase(), color: isCompleted? const Color(0xFF2E7D32): const Color(0xFFEF6C00), icon: isCompleted? Icons.check_circle: Icons.hourglass_top),
                  ]),
                  const Divider(height:24),
                  _Row(label: 'Procurement value', value: '₹${p.totalAmount.toStringAsFixed(0)}'),
                  const SizedBox(height:8),
                  _Row(label: 'Booking', value: '${booking.tokenNumber} • ${booking.centreName}'),
                  if (p.paymentDate != null) ...[const SizedBox(height:8), _Row(label: 'Payment date', value: AppDateUtils.formatDate(p.paymentDate!))],
                  if (p.transactionId != null) ...[const SizedBox(height:8), _Row(label: 'Transaction', value: p.transactionId!)],
                ])),
                const SizedBox(height:12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: isCompleted? const Color(0xFFE8F5E9): const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12), border: Border.all(color: isCompleted? const Color(0xFFA5D6A7): const Color(0xFFFFCC80))),
                  child: Row(children:[
                    Icon(isCompleted? Icons.check_circle: Icons.info, color: isCompleted? const Color(0xFF2E7D32): const Color(0xFFEF6C00)),
                    const SizedBox(width:10),
                    Expanded(child: Text(isCompleted? 'Payment completed and credited to your bank account.' : 'Payment processing. Will be credited within 48 hours after procurement.', style: TextStyle(color: isCompleted? const Color(0xFF1B5E20): const Color(0xFFE65100), fontSize:12))),
                  ]),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}
class _Row extends StatelessWidget{
  final String label; final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context)=> Row(children:[SizedBox(width:120, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize:12))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize:13)))]);
}
final _activeBookingProvider = FutureProvider<Booking?>((ref) async {
  final auth = await ref.read(authRepositoryProvider).getCurrentUser();
  if (auth==null) return null;
  return ref.watch(slotRepositoryProvider).getActiveBooking(auth.id);
});
