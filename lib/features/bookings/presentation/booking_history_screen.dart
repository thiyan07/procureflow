import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_error.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/providers.dart';
import '../../../models/booking.dart';

class BookingHistoryScreen extends ConsumerStatefulWidget {
  const BookingHistoryScreen({super.key});
  @override
  ConsumerState<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends ConsumerState<BookingHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = ref.watch(authStateProvider);
    return Scaffold(
      appBar: AppBar(title: Text(loc.booking)),
      body: auth.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,s) => ErrorState(message: e.toString()),
        data: (user) {
          if (user == null) return const EmptyState(title: 'Not logged in', subtitle: 'Login to view bookings', icon: Icons.person_off);
          final bookingsAsync = ref.watch(_bookingsProvider(user.id));
          return bookingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e,s) => ErrorState(message: e.toString(), onRetry:()=> ref.refresh(_bookingsProvider(user.id))),
            data: (list) {
              if (list.isEmpty) return EmptyState(title: 'No bookings yet', subtitle: 'Book a slot to see history here', icon: Icons.history, actionLabel: 'Book Slot', onAction: ()=> context.push('/centres'));
              return RefreshIndicator(
                onRefresh: () async => ref.refresh(_bookingsProvider(user.id)),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_,__)=> const SizedBox(height:8),
                  itemBuilder: (c,i){
                    final b = list[i];
                    final isCancelled = b.queueStatus == QueueStatus.cancelled;
                    final isActive = b.queueStatus != QueueStatus.completed && b.queueStatus != QueueStatus.cancelled;
                    return AppCard(
                      onTap: ()=> _showDetails(context, b),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                        Row(children:[
                          Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:4), decoration: BoxDecoration(color: isCancelled? Colors.grey.shade200: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)), child: Text(b.tokenNumber, style: TextStyle(fontWeight: FontWeight.w800, fontSize:12, color: isCancelled? Colors.grey: const Color(0xFF1B5E20)))),
                          const SizedBox(width:8),
                          Expanded(child: Text(b.centreName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize:13), overflow: TextOverflow.ellipsis)),
                          StatusChip(label: b.queueStatus.name.toUpperCase(), color: isActive? AppTheme.primaryGreen: isCancelled? Colors.grey: AppTheme.success, icon: isCancelled? Icons.cancel: Icons.schedule),
                        ]),
                        const SizedBox(height:6),
                        Row(children:[
                          _Mini(label:'Date', value: AppDateUtils.formatDate(b.date)),
                          const SizedBox(width:12),
                          _Mini(label:'Slot', value: AppDateUtils.formatTime(b.slotStart)),
                          const SizedBox(width:12),
                          _Mini(label:'Commodity', value: '${b.commodity} • ${b.quantityQuintal}q'),
                        ]),
                        if (isActive) Padding(
                          padding: const EdgeInsets.only(top:10),
                          child: Row(children:[
                            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.edit_calendar, size:16), label: const Text('Reschedule'), onPressed: ()=> _rescheduleSheet(b))),
                            const SizedBox(width:8),
                            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.cancel_outlined, size:16), label: const Text('Cancel'), style: OutlinedButton.styleFrom(foregroundColor: Colors.red), onPressed: ()=> _cancel(b))),
                          ]),
                        ),
                      ]),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetails(BuildContext ctx, Booking b){
    final loc = AppLocalizations.of(ctx)!;
    showModalBottomSheet(context: ctx, builder: (_)=> Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[
      Text('${loc.booking} ${b.tokenNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize:16)),
      const SizedBox(height:8),
      _Row(label: loc.centres, value: b.centreName),
      _Row(label: loc.selectDate, value: AppDateUtils.formatDate(b.date)),
      _Row(label: loc.bookSlot, value: '${AppDateUtils.formatTime(b.slotStart)} - ${AppDateUtils.formatTime(b.slotEnd)}'),
      _Row(label: loc.selectCommodity, value: b.commodity),
      _Row(label: loc.estimatedQuantity, value: '${b.quantityQuintal} ${loc.quintal}'),
      _Row(label: loc.procurementStatus, value: b.queueStatus.name),
      _Row(label: loc.estimatedWaiting, value: AppDateUtils.formatDate(b.createdAt)),
      const SizedBox(height:12),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.qr_code), label: Text(loc.showToken), onPressed: ()=> context.push('/token'))),
    ])));
  }

  Future<void> _cancel(Booking b) async{
    final ok = await showDialog<bool>(context: context, builder: (_)=> AlertDialog(title: const Text('Cancel Booking'), content: Text('Cancel ${b.tokenNumber} at ${b.centreName}? Slot will be freed.'), actions:[ TextButton(onPressed: ()=> Navigator.pop(context,false), child: const Text('Keep')), FilledButton(onPressed: ()=> Navigator.pop(context,true), child: const Text('Cancel Booking'))]));
    if (ok != true) return;
    try{
      await ref.read(apiClientProvider).post('/api/v1/bookings/${b.id}/cancel');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking ${b.tokenNumber} cancelled')));
      ref.invalidate(_bookingsProvider);
      ref.invalidate(authStateProvider);
    }catch(e){ if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyMessage(e)))); }
  }

  Future<void> _rescheduleSheet(Booking b) async{
    // fetch slots for same centre + date+1
    final nextDay = b.date.add(const Duration(days:1));
    try{
      final repo = ref.read(slotRepositoryProvider);
      final slots = await repo.getSlots(b.centreId, nextDay);
      if (!mounted) return;
      showModalBottomSheet(context: context, builder: (_)=> DraggableScrollableSheet(
        expand:false, initialChildSize:0.7, builder: (ctx, scroll)=> ListView(padding: const EdgeInsets.all(16), children:[
          const Text('Reschedule — select new slot', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height:4),
          Text('Current: ${AppDateUtils.formatDate(b.date)} • ${AppDateUtils.formatTime(b.slotStart)}', style: const TextStyle(color: Colors.black54, fontSize:12)),
          const SizedBox(height:12),
          ...slots.map((s)=> Card(child: ListTile(title: Text(AppDateUtils.formatTime(s.start)), subtitle: Text('${s.available} available • ${s.booked}/${s.capacity}'), trailing: s.isFull? const Text('FULL', style: TextStyle(color: Colors.red)): const Icon(Icons.chevron_right), onTap: s.isFull? null: () async{
            Navigator.pop(ctx);
            try{
              await ref.read(apiClientProvider).post('/api/v1/bookings/${b.id}/reschedule', body:{'new_slot_id': s.id});
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rescheduled to ${AppDateUtils.formatTime(s.start)}')));
              ref.invalidate(_bookingsProvider);
            }catch(e){ if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
          }))),
          if (slots.isEmpty) const Text('No slots available for next day', style: TextStyle(color: Colors.black45)),
        ]),
      ));
    }catch(e){ if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyMessage(e)))); }
  }
}

class _Mini extends StatelessWidget{
  final String label; final String value;
  const _Mini({required this.label, required this.value});
  @override
  Widget build(BuildContext c)=> Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[ Text(label, style: const TextStyle(fontSize:10, color: Colors.black54)), Text(value, style: const TextStyle(fontSize:12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)]));
}
class _Row extends StatelessWidget{
  final String label; final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext c)=> Padding(padding: const EdgeInsets.symmetric(vertical:2), child: Row(children:[ SizedBox(width:80, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize:11))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize:12)))]));
}

final _bookingsProvider = FutureProvider.family<List<Booking>, String>((ref, farmerId) async {
  return ref.watch(slotRepositoryProvider).getBookingsForFarmer(farmerId);
});
