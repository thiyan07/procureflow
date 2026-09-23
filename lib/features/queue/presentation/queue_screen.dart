import '../../../core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/providers.dart';
import '../../../models/booking.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final bookingAsync = ref.watch(_activeBookingProvider);
    return Scaffold(
      appBar: AppBar(title: Text(loc.todayQueue)),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,s) => ErrorState(message: e.toString()),
        data: (booking) {
          if (booking == null) return const EmptyState(title: 'No booking', subtitle: 'Book a slot first', icon: Icons.hourglass_empty);
          return StreamBuilder<QueueState>(
            stream: ref.read(queueRepositoryProvider).watchQueue(booking.id),
            builder: (context, snap) {
              return FutureBuilder<QueueState>(
                future: ref.read(queueRepositoryProvider).getQueueStatus(booking.id),
                builder: (context, initial) {
                  final q = snap.data ?? initial.data;
                  if (q == null) return const Center(child: CircularProgressIndicator());
                  return FutureBuilder<Map<String, dynamic>>(
                    future: ref.read(queueRepositoryProvider).getQueueCorrection(booking.id),
                    builder: (context, corrSnap) {
                      final corr = corrSnap.data ?? {};
                      final bool correctionApplied = corr['correction_applied'] == true || corr['correctionApplied'] == true;
                      final bool duplicateRisk = corr['duplicate_risk'] == true || corr['duplicateRisk'] == true;
                      final bool missedCall = corr['missed_call_flag'] == true || corr['missedCallFlag'] == true;
                      final int gap = (corr['position_gap'] as int?) ?? (corr['gap'] as int?) ?? 0;
                      final int farmersAheadCorrected = (corr['farmers_ahead_corrected'] as int?) ?? (corr['farmersAheadCorrected'] as int?) ?? q.farmersAhead;
                      final String? correctionNote = corr['correction_note'] as String? ?? corr['correctionNote'] as String?;
                      return FutureBuilder(
                    future: ref.read(aiRepositoryProvider).predictWaitingTime(farmersAhead: q.farmersAhead, avgProcessingMinutes: 3, activeCounters: 3),
                    builder: (context, predSnap) {
                      final pred = predSnap.data;
                      return ListView(padding: const EdgeInsets.all(16), children: [
                        // Fraud / correction banners (deterministic)
                        if (correctionApplied)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFCC02))),
                            child: Row(children: [
                              const Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(correctionNote ?? 'Queue position corrected — processing not counted', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFEF6C00))),
                                const SizedBox(height: 2),
                                Text(AppLocalizations.of(context)!.queueCorrectionNote, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                if (farmersAheadCorrected != q.farmersAhead)
                                  Text('Corrected ahead: $farmersAheadCorrected (was ${corr['farmers_ahead_naive'] ?? q.farmersAhead})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ])),
                            ]),
                          ),
                        if (duplicateRisk)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE53935))),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935), size: 18),
                              const SizedBox(width: 6),
                              const Text('Duplicate booking risk', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w700, fontSize: 12)),
                              const SizedBox(width: 6),
                              StatusChip(label: 'FRAUD CHECK', color: const Color(0xFFE53935), icon: Icons.shield),
                            ]),
                          ),
                        if (missedCall)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFB8C00))),
                            child: Row(children: [
                              const Icon(Icons.call_missed, color: Color(0xFFFB8C00)),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Missed call detected — position gap $gap >2 indicates skipped token', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF6C00)))),
                            ]),
                          ),
                        AppCard(child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            _Box(label: 'Current', value: '#${q.currentTokenOrdinal}'),
                            Icon(Icons.arrow_forward, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            _Box(label: 'Your token', value: q.tokenNumber, highlight: true),
                          ]),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: q.farmersAhead==0?1: (1 - (q.farmersAhead/15).clamp(0,1)), minHeight: 8, borderRadius: BorderRadius.circular(4)),
                          const SizedBox(height: 8),
                          Builder(builder: (ctx){
                            final l = AppLocalizations.of(ctx)!;
                            return Column(children:[
                              Text(l.farmersAhead(q.farmersAhead.toString()), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                                child: Row(children: [
                                  const Icon(Icons.schedule, color: Color(0xFFEF6C00)),
                                  const SizedBox(width:8),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${l.estimatedWaiting} ${l.minutes(q.estimatedWaitMinutes.toString())}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF6C00))),
                                    if (pred != null) Text(pred.reasoning, style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  ])),
                                  StatusChip(label: q.status.name.toUpperCase(), color: const Color(0xFF2E7D32), icon: Icons.hourglass_top),
                                ]),
                              ),
                            ]);
                          }),
                        ])),
                        const SizedBox(height: 12),
                        Builder(builder: (ctx){
                          final l = AppLocalizations.of(ctx)!;
                          return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.queueMessages, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            _Step(done: true, title: l.bookingConfirmed, subtitle: l.token),
                            _Step(done: q.farmersAhead < 10, title: l.yourTurnApproaching, subtitle: l.centreOpen),
                            _Step(done: q.farmersAhead==0, title: l.called, subtitle: l.centreStatus),
                            _Step(done: q.status==QueueStatus.processing, title: l.processing, subtitle: l.weighment),
                          ]));
                        }),
                        const SizedBox(height:12),
                        Text('Live updates every 3 seconds (mock). WebSocket-ready architecture.', textAlign: TextAlign.center, style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ]);
                    },
                      );
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
    child: Column(children: [Text(label, style: TextStyle(fontSize:11, color: highlight? Colors.white70: Theme.of(context).colorScheme.onSurfaceVariant)), Text(value, style: TextStyle(fontSize:20, fontWeight: FontWeight.w800, color: highlight? Colors.white: Theme.of(context).colorScheme.onSurface))]),
  );
}
class _Step extends StatelessWidget {
  final bool done; final String title; final String subtitle;
  const _Step({required this.done, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context)=> Padding(padding: const EdgeInsets.symmetric(vertical:6), child: Row(children:[
    Icon(done? Icons.check_circle: Icons.radio_button_unchecked, color: done? const Color(0xFF2E7D32): Colors.grey, size:20),
    const SizedBox(width:10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: done? Theme.of(context).colorScheme.onSurface: Theme.of(context).colorScheme.onSurfaceVariant)), Text(subtitle, style: TextStyle(fontSize:12, color: Theme.of(context).colorScheme.onSurfaceVariant))])),
  ]));
}

final _activeBookingProvider = FutureProvider<Booking?>((ref) async {
  final auth = await ref.read(authRepositoryProvider).getCurrentUser();
  if (auth==null) return null;
  return ref.watch(slotRepositoryProvider).getActiveBooking(auth.id);
});
