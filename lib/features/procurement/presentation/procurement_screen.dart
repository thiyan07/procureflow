import '../../../core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';
import '../../../models/booking.dart';
import '../../../core/utils/date_utils.dart';

class ProcurementScreen extends ConsumerWidget {
  const ProcurementScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(_activeBookingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Procurement Tracking')),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,s) => ErrorState(message: e.toString()),
        data: (booking) {
          if (booking==null) return const EmptyState(title: 'No procurement', subtitle: 'Book a slot and complete queue.', icon: Icons.timeline_outlined);
          return FutureBuilder(
            future: ref.read(procurementRepositoryProvider).getProcurementTimeline(booking.id),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final steps = snap.data!;
              return ListView(padding: const EdgeInsets.all(16), children: [
                AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(booking.centreName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${booking.commodity} • ${booking.quantityQuintal} quintal • ${booking.tokenNumber}', style: const TextStyle(color: Colors.black54, fontSize:12)),
                ])),
                const SizedBox(height:12),
                AppCard(child: Column(children: steps.map((s) => _TimelineTile(step: s)).toList())),
                const SizedBox(height:12),
                // Demo advance button
                if (booking.procurementStage != ProcurementStage.paymentCompleted)
                  ElevatedButton.icon(icon: const Icon(Icons.arrow_forward), label: const Text('Advance Stage (Demo)'), onPressed: () async {
                    final stages = ProcurementStage.values;
                    final idx = stages.indexOf(booking.procurementStage);
                    if (idx < stages.length-1) {
                      await ref.read(procurementRepositoryProvider).advanceStage(booking.id, stages[idx+1]);
                      ref.invalidate(_activeBookingProvider);
                    }
                  }),
              ]);
            },
          );
        },
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final TimelineStep step;
  const _TimelineTile({required this.step});
  @override
  Widget build(BuildContext context) {
    final color = step.isCompleted? const Color(0xFF2E7D32): step.isCurrent? const Color(0xFFEF6C00): Colors.grey;
    final icon = step.isCompleted? Icons.check_circle: step.isCurrent? Icons.sync: Icons.radio_button_unchecked;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical:8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width:12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(step.title, style: TextStyle(fontWeight: FontWeight.w600, color: step.isCurrent||step.isCompleted? Colors.black87: Colors.black45)),
          Text(step.subtitle, style: const TextStyle(fontSize:12, color: Colors.black54)),
          if (step.timestamp != null) Text(AppDateUtils.formatTime(step.timestamp!), style: const TextStyle(fontSize:11, color: Color(0xFF2E7D32))),
        ])),
        if (step.isCurrent) Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:4), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(20)), child: const Text('IN PROGRESS', style: TextStyle(fontSize:10, fontWeight: FontWeight.w700, color: Color(0xFFEF6C00)))),
        if (step.isCompleted) const Icon(Icons.done, size:16, color: Color(0xFF2E7D32)),
      ]),
    );
  }
}

final _activeBookingProvider = FutureProvider<Booking?>((ref) async {
  final auth = await ref.read(authRepositoryProvider).getCurrentUser();
  if (auth==null) return null;
  return ref.watch(slotRepositoryProvider).getActiveBooking(auth.id);
});
