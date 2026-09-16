import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/utils/date_utils.dart';
import '../../../services/providers.dart';
import '../../../models/booking.dart';

class TokenScreen extends ConsumerWidget {
  const TokenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(_activeBookingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Token')),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,s) => ErrorState(message: e.toString()),
        data: (booking){
          if (booking==null) return EmptyState(title: 'No active token', subtitle: 'Book a slot to generate your token.', icon: Icons.confirmation_number_outlined, actionLabel: 'Book Slot', onAction: ()=> context.push('/centres'));
          return ListView(padding: const EdgeInsets.all(16), children: [
            // Token card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE0E5DE)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius:12, offset: const Offset(0,4))]),
              child: Column(children: [
                const Text('TOKEN', style: TextStyle(letterSpacing:2, fontWeight: FontWeight.w800, color: Colors.black54, fontSize:12)),
                const SizedBox(height:6),
                Text(booking.tokenNumber, style: const TextStyle(fontSize:48, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
                const SizedBox(height:4),
                StatusChip(label: booking.queueStatus.name.toUpperCase(), color: const Color(0xFF2E7D32), icon: Icons.schedule),
                const SizedBox(height:16),
                QrImageView(data: 'PROCUREFLOW|${booking.id}|${booking.tokenNumber}|${booking.centreId}', version: QrVersions.auto, size: 160),
                const SizedBox(height:6),
                const Text('Show this QR at the centre gate', style: TextStyle(fontSize:11, color: Colors.black54)),
                const Divider(height:32),
                _Row(label: 'Centre', value: booking.centreName),
                const SizedBox(height:8),
                _Row(label: 'Date', value: AppDateUtils.formatDate(booking.date)),
                const SizedBox(height:8),
                _Row(label: 'Slot', value: AppDateUtils.formatTime(booking.slotStart)),
                const SizedBox(height:8),
                _Row(label: 'Commodity', value: '${booking.commodity} • ${booking.quantityQuintal} quintal'),
              ]),
            ),
            const SizedBox(height:16),
            // Queue preview
            FutureBuilder(
              future: ref.read(queueRepositoryProvider).getQueueStatus(booking.id),
              builder: (context, snap){
                if (!snap.hasData) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())));
                final q = snap.data!;
                return AppCard(child: Column(children:[
                  Row(children:[
                    _Mini(label:'Current', value:'#${q.currentTokenOrdinal}'),
                    const SizedBox(width:16),
                    _Mini(label:'Your token', value: q.tokenNumber),
                    const Spacer(),
                    Container(padding: const EdgeInsets.symmetric(horizontal:10,vertical:6), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(20)), child: Text('${q.estimatedWaitMinutes} min wait', style: const TextStyle(fontWeight:FontWeight.w700, fontSize:12, color: Color(0xFFEF6C00)))),
                  ]),
                  const SizedBox(height:12),
                  LinearProgressIndicator(value: q.farmersAhead==0?1: 1 - (q.farmersAhead/20).clamp(0,1), backgroundColor: const Color(0xFFE0E5DE), color: const Color(0xFF2E7D32)),
                  const SizedBox(height:8),
                  Text('${q.farmersAhead} farmers ahead', style: const TextStyle(color: Colors.black54, fontSize:12)),
                  const SizedBox(height:12),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.track_changes), label: const Text('TRACK LIVE QUEUE'), onPressed: ()=> context.push('/queue'))),
                ]));
              },
            ),
          ]);
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label; final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context)=> Row(children:[
    SizedBox(width:90, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize:12))),
    Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize:13))),
  ]);
}
class _Mini extends StatelessWidget {
  final String label; final String value;
  const _Mini({required this.label, required this.value});
  @override
  Widget build(BuildContext context)=> Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
    Text(label, style: const TextStyle(fontSize:11, color: Colors.black54)),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize:16)),
  ]);
}

final _activeBookingProvider = FutureProvider<Booking?>((ref) async {
  final auth = await ref.read(authRepositoryProvider).getCurrentUser();
  if (auth==null) return null;
  return ref.watch(slotRepositoryProvider).getActiveBooking(auth.id);
});
