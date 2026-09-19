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
                const SizedBox(height:12),
                AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                  const Text('Payment Timeline', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height:8),
                  _PayStep(title:'Booking Confirmed', subtitle:'Token generated', done:true, current:false),
                  _PayStep(title:'Procurement', subtitle: booking.procurementStage.name, done: booking.procurementStage != ProcurementStage.bookingConfirmed, current: p.status==PaymentStatus.pending),
                  _PayStep(title:'Payment Processing', subtitle:'Bank verification', done: p.status==PaymentStatus.processing || p.status==PaymentStatus.completed, current: p.status==PaymentStatus.processing),
                  _PayStep(title:'Payment Completed', subtitle: p.transactionId ?? 'Awaiting credit', done: p.status==PaymentStatus.completed, current: p.status==PaymentStatus.completed),
                ])),
              ]);
            },
          );
        },
      ),
    );
  }
}
class _PayStep extends StatelessWidget{
  final String title; final String subtitle; final bool done; final bool current;
  const _PayStep({required this.title, required this.subtitle, required this.done, required this.current});
  @override
  Widget build(BuildContext context){
    final color = done? const Color(0xFF2E7D32): current? const Color(0xFFEF6C00): Colors.grey;
    final icon = done? Icons.check_circle: current? Icons.sync: Icons.radio_button_unchecked;
    return Padding(padding: const EdgeInsets.symmetric(vertical:6), child: Row(children:[
      Icon(icon, color: color, size:20),
      const SizedBox(width:10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize:12, color: done||current? Colors.black87: Colors.black45)),
        Text(subtitle, style: const TextStyle(fontSize:11, color: Colors.black54)),
      ])),
      if (current) Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(20)), child: const Text('CURRENT', style: TextStyle(fontSize:9, fontWeight: FontWeight.w700, color: Color(0xFFEF6C00)))),
    ]));
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
