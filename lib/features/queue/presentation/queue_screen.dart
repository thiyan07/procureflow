import '../../../core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';
import '../../../models/booking.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(_activeBookingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Live Queue')),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,s) => ErrorState(message: e.toString()),
        data: (booking) {
          if (booking == null) return const EmptyState(title: 'No booking', subtitle: 'Book a slot first', icon: Icons.hourglass_empty);
          return StreamBuilder<QueueState>(
            stream: ref.read(queueRepositoryProvider).watchQueue(booking.id),
            builder: (context, snap) {
              // also fetch initial synchronously
              return FutureBuilder<QueueState>(
                future: ref.read(queueRepositoryProvider).getQueueStatus(booking.id),
                builder: (context, initial) {
                  final q = snap.data ?? initial.data;
                  if (q == null) return const Center(child: CircularProgressIndicator());
                  // also fetch AI prediction
                  return FutureBuilder(
                    future: ref.read(aiRepositoryProvider).predictWaitingTime(farmersAhead: q.farmersAhead, avgProcessingMinutes: 3, activeCounters: 3),
                    builder: (context, predSnap) {
                      final pred = predSnap.data;
                      return ListView(padding: const EdgeInsets.all(16), children: [
                        AppCard(child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            _Box(label: 'Current', value: '#${q.currentTokenOrdinal}'),
                            const Icon(Icons.arrow_forward, color: Colors.black26),
                            _Box(label: 'Your token', value: q.tokenNumber, highlight: true),
                          ]),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: q.farmersAhead==0?1: (1 - (q.farmersAhead/15).clamp(0,1)), minHeight: 8, borderRadius: BorderRadius.circular(4)),
                          const SizedBox(height: 8),
                          Text('${q.farmersAhead} farmers ahead', style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [
                              const Icon(Icons.schedule, color: Color(0xFFEF6C00)),
                              const SizedBox(width:8),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Estimated waiting: ${q.estimatedWaitMinutes} min', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF6C00))),
                                if (pred != null) Text(pred.reasoning, style: const TextStyle(fontSize:11, color: Colors.black54)),
                              ])),
                              StatusChip(label: q.status.name.toUpperCase(), color: const Color(0xFF2E7D32), icon: Icons.hourglass_top),
                            ]),
                          ),
                        ])),
                        const SizedBox(height: 12),
                        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Queue Timeline', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          _Step(done: true, title: 'Booking Confirmed', subtitle: 'Token generated'),
                          _Step(done: q.farmersAhead < 10, title: 'Your turn approaching', subtitle: 'Stay near centre'),
                          _Step(done: q.farmersAhead==0, title: 'Called', subtitle: 'Proceed to counter'),
                          _Step(done: q.status==QueueStatus.processing, title: 'Processing', subtitle: 'Weighment in progress'),
                        ])),
                        const SizedBox(height:12),
                        const Text('Live updates every 3 seconds (mock). WebSocket-ready architecture.', textAlign: TextAlign.center, style: TextStyle(fontSize:11, color: Colors.black45)),
                      ]);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _Box extends StatelessWidget {
  final String label; final String value; final bool highlight;
  const _Box({required this.label, required this.value, this.highlight=false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal:18, vertical:12),
    decoration: BoxDecoration(color: highlight? const Color(0xFF1B5E20): Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E5DE))),
    child: Column(children: [Text(label, style: TextStyle(fontSize:11, color: highlight? Colors.white70: Colors.black54)), Text(value, style: TextStyle(fontSize:20, fontWeight: FontWeight.w800, color: highlight? Colors.white: Colors.black87))]),
  );
}
class _Step extends StatelessWidget {
  final bool done; final String title; final String subtitle;
  const _Step({required this.done, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context)=> Padding(padding: const EdgeInsets.symmetric(vertical:6), child: Row(children:[
    Icon(done? Icons.check_circle: Icons.radio_button_unchecked, color: done? const Color(0xFF2E7D32): Colors.grey, size:20),
    const SizedBox(width:10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: done? Colors.black87: Colors.black45)), Text(subtitle, style: const TextStyle(fontSize:12, color: Colors.black54))])),
  ]));
}

final _activeBookingProvider = FutureProvider<Booking?>((ref) async {
  final auth = await ref.read(authRepositoryProvider).getCurrentUser();
  if (auth==null) return null;
  return ref.watch(slotRepositoryProvider).getActiveBooking(auth.id);
});
