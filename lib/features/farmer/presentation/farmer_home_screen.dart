import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';
import '../../../models/booking.dart';
import '../../../core/utils/date_utils.dart';

class FarmerHomeScreen extends ConsumerWidget {
  const FarmerHomeScreen({super.key});

  String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepo = ref.watch(authRepositoryProvider);
    return FutureBuilder(
      future: authRepo.getCurrentUser(),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final user = snap.data;
        final farmer = user?.farmer;
        final name = farmer?.fullName.split(' ').first ?? 'Farmer';
        return Scaffold(
          appBar: AppBar(
            title: const Text('ProcureFlow'),
            actions: [
              IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.push('/notifications')),
              IconButton(icon: const Icon(Icons.person_outline), onPressed: () => context.push('/profile')),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(_activeBookingProvider),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width:8,height:8,decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                  const SizedBox(width:6),
                  const Text('DEMO MODE • Mock backend', style: TextStyle(fontSize:11, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
                ]),
              ),
              const SizedBox(height: 12),
              Text('${greeting()}, $name 👋', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(farmer != null ? '${farmer.village}, ${farmer.district} • ${farmer.primaryCommodity}' : '', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Consumer(builder: (context, ref, _) {
                final asyncBooking = ref.watch(_activeBookingProvider);
                return asyncBooking.when(
                  loading: () => const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))),
                  error: (e,s) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e'))),
                  data: (booking) {
                    if (booking == null) {
                      return AppCard(child: Column(children: [
                        const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text('No active procurement booking', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        const Text('Book a slot at your nearest centre to get a token.', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        PrimaryButton(label: 'Book a Slot', icon: Icons.calendar_today, onPressed: () => context.push('/centres')),
                      ]));
                    }
                    return _ActiveBookingCard(booking: booking);
                  },
                );
              }),
              const SizedBox(height: 16),
              Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.2,
                children: [
                  _ActionCard(icon: Icons.store, label: 'Book Slot', color: AppTheme.primaryGreen, onTap: () => context.push('/centres')),
                  _ActionCard(icon: Icons.confirmation_number, label: 'My Token', color: const Color(0xFF1565C0), onTap: () => context.push('/token')),
                  _ActionCard(icon: Icons.timeline, label: 'Procurement', color: const Color(0xFF6A1B9A), onTap: () => context.push('/procurement')),
                  _ActionCard(icon: Icons.payments_outlined, label: 'Payment', color: const Color(0xFFEF6C00), onTap: () => context.push('/payment')),
                ],
              ),
              const SizedBox(height: 16),
              AppCard(
                onTap: () => context.push('/assistant'),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.smart_toy_outlined, color: Color(0xFF4527A0))),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AI Assistant', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Ask: Where is my token?', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ])),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            ]),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/centres'),
            icon: const Icon(Icons.add),
            label: const Text('Book Slot'),
          ),
        );
      },
    );
  }
}

final _activeBookingProvider = FutureProvider<Booking?>((ref) async {
  final auth = await ref.watch(authRepositoryProvider).getCurrentUser();
  if (auth == null) return null;
  final slotRepo = ref.watch(slotRepositoryProvider);
  return slotRepo.getActiveBooking(auth.id);
});

class _ActiveBookingCard extends ConsumerWidget {
  final Booking booking;
  const _ActiveBookingCard({required this.booking});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(_queueProvider(booking.id));
    return AppCard(
      padding: const EdgeInsets.all(0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Color(0xFFE8F5E9), borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
          child: Row(children: [
            const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
            const SizedBox(width: 8),
            const Text('SLOT CONFIRMED', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.success, letterSpacing: 1.1, fontSize: 12)),
            const Spacer(),
            StatusChip(label: booking.queueStatus.name.toUpperCase(), color: AppTheme.success, icon: Icons.schedule),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppDateUtils.formatTime(booking.slotStart), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                Text(booking.centreName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(AppDateUtils.formatDate(booking.date), style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  const Text('TOKEN', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1)),
                  Text(booking.tokenNumber, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            queueAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e,s) => Text('Queue error: $e'),
              data: (q) => Column(children: [
                Row(children: [
                  _MiniStat(label: 'Farmers ahead', value: '${q.farmersAhead}'),
                  const SizedBox(width: 16),
                  _MiniStat(label: 'Est. wait', value: '${q.estimatedWaitMinutes} min'),
                  const Spacer(),
                  const Icon(Icons.groups_outlined, size: 18, color: Colors.black45),
                  const SizedBox(width:4),
                  Text('Now: #${q.currentTokenOrdinal}', style: const TextStyle(fontSize:12, color: Colors.black54)),
                ]),
                const SizedBox(height:12),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.track_changes), label: const Text('TRACK QUEUE'), onPressed: () => context.push('/queue'))),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

final _queueProvider = FutureProvider.family<QueueState, String>((ref, bookingId) async {
  final repo = ref.watch(queueRepositoryProvider);
  return repo.getQueueStatus(bookingId);
});

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
    Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
  ]);
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return AppCard(padding: const EdgeInsets.all(14), onTap: onTap, child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha:0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
      const Icon(Icons.chevron_right, size: 18, color: Colors.black26),
    ]));
  }
}
