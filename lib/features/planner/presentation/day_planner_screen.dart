import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/storage/local_storage.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/providers.dart';
import '../../../models/booking.dart';
import '../../../models/payment.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';

// My Procurement Day — single most useful farmer screen per spec
class DayPlannerScreen extends ConsumerStatefulWidget {
  const DayPlannerScreen({super.key});
  @override
  ConsumerState<DayPlannerScreen> createState()=> _DayPlannerScreenState();
}
class _DayPlannerScreenState extends ConsumerState<DayPlannerScreen>{
  bool _reminderOn = true;
  Map<String,bool> _docsCompleted = {};
  @override
  void initState(){
    super.initState();
    _loadDocs();
  }
  void _loadDocs(){
    // load from LocalStorage per booking
  }

  String _nextAction(Booking b, QueueState? q, List<TimelineStep>? tl, dynamic payment){
    final ahead = q?.farmersAhead ?? 0;
    final status = q?.status ?? b.queueStatus;
    final stage = tl?.firstWhere((t)=>t.isCurrent, orElse: ()=>tl!.first).title ?? '';
    if (status == QueueStatus.waiting){
      if (ahead <=2 && ahead>0) return 'Turn approaching — proceed to gate and show QR';
      if (ahead==0) return 'You are next — stay near centre';
      return 'Reach 30 min early • $ahead farmers ahead • ~${q?.estimatedWaitMinutes??0} min wait';
    }
    if (status == QueueStatus.called) return 'Token CALLED — proceed to counter NOW';
    if (status == QueueStatus.arrived) return 'Checked-in — awaiting weighment';
    if (stage.contains('Weighment')) return 'Weighment in progress';
    if (stage.contains('Quality')) return 'Quality check — await grading';
    if (stage.contains('Procurement')) return 'Procurement approval';
    if (payment!=null && payment.status.toString().contains('completed')) return 'Payment credited — check receipt';
    if (stage.contains('Completed')) return 'Procurement completed — payment pending';
    return 'Show QR at gate • Keep documents ready';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bookingAsync = ref.watch(_activeBookingProvider);
    return Scaffold(
      appBar: AppBar(title: Text(loc.myProcurementDay)),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,s) => ErrorState(message: e.toString(), onRetry: ()=> ref.invalidate(_activeBookingProvider)),
        data: (booking) {
          if (booking == null) {
            return EmptyState(title: 'No upcoming procurement', subtitle: 'Book a slot to see your day plan', icon: Icons.event_note, actionLabel: 'Book Slot', onAction: ()=> context.push('/centres'));
          }
          return FutureBuilder(
            future: Future.wait([
              ref.read(queueRepositoryProvider).getQueueStatus(booking.id),
              ref.read(procurementRepositoryProvider).getProcurementTimeline(booking.id),
              ref.read(paymentRepositoryProvider).getPayment(booking.id).catchError((_)=> null),
              ref.read(apiClientProvider).get('/api/v1/centres/${booking.centreId}/status').catchError((_)=> {}),
              ref.read(apiClientProvider).get('/api/v1/centres/${booking.centreId}/capacity').catchError((_)=> {}),
              ref.read(apiClientProvider).get('/api/v1/centres/${booking.centreId}/documents?commodity=${Uri.encodeComponent(booking.commodity.split(',').first.trim())}').catchError((_)=> {}),
            ]),
            builder: (c, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final queue = snap.data![0] as QueueState?;
              final timeline = snap.data![1] as List<TimelineStep>?;
              final dynamic payment = snap.data![2];
              final centreStatus = snap.data![3] as Map<String,dynamic>? ?? {};
              final capacity = snap.data![4] as Map<String,dynamic>? ?? {};
              final docsData = snap.data![5] as Map<String,dynamic>? ?? {};
              final docsList = (docsData['documents'] as List?)?.cast<Map<String,dynamic>>() ?? _docs.map((d)=> {'label': d, 'required': !d.contains('Land'), 'description': ''}).toList();
              final wait = queue?.estimatedWaitMinutes ?? 0;
              final farmersAhead = queue?.farmersAhead ?? 0;
              final eta = DateTime.now().add(Duration(minutes: wait));
              final centreIsOpen = (centreStatus['is_open'] as bool?) ?? true;
              final centreStatusStr = (centreStatus['centre'] is Map ? (centreStatus['centre']['status'] as String? ?? 'Open') : 'Open');
              final nextAction = _nextAction(booking, queue, timeline, payment);
              final totalQty = booking.commoditiesDisplay;
              return ListView(padding: const EdgeInsets.all(16), children: [
                // Header centre + status
                AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.location_on, color: Color(0xFF2E7D32)),
                    const SizedBox(width:8),
                    Expanded(child: Text(booking.centreName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize:15))),
                    StatusChip(label: centreStatusStr.toUpperCase(), color: centreIsOpen ? const Color(0xFF2E7D32) : Colors.red, icon: centreIsOpen ? Icons.check_circle : Icons.pause_circle),
                  ]),
                  if (centreStatusStr.toLowerCase()!='open') Container(margin: const EdgeInsets.only(top:8), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.warning, color: Colors.red, size:16), const SizedBox(width:6), Expanded(child: Text('Centre $centreStatusStr — may affect booking. See alternative slots.', style: const TextStyle(fontSize:11, color: Colors.red)))])),
                  const SizedBox(height:6),
                  _Row(label: loc.selectDate, value: AppDateUtils.formatDate(booking.date)),
                  _Row(label: loc.bookSlot, value: AppDateUtils.formatTime(booking.slotStart)),
                  _Row(label: loc.selectCommodity, value: booking.commoditiesDisplay),
                  if (booking.commodities != null && booking.commodities!.length>1) Padding(padding: const EdgeInsets.only(left:90), child: Text(loc.multiCommoditySupported, style: const TextStyle(fontSize:10, color: Color(0xFF2E7D32)))),
                  _Row(label: loc.estimatedQuantity, value: totalQty),
                  const Divider(height:20),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:8), decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(10)), child: Column(children: [const Text('TOKEN', style: TextStyle(color: Colors.white70, fontSize:10)), Text(booking.tokenNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize:16)) ])),
                    const SizedBox(width:12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(loc.farmersAhead(farmersAhead.toString()), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${loc.estimatedWaiting} ${loc.minutes(wait.toString())} • ETA ${AppDateUtils.formatTime(eta)}', style: TextStyle(fontSize:12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height:4),
                      LinearProgressIndicator(value: farmersAhead==0?1: 1-(farmersAhead/15).clamp(0,1), minHeight:6, backgroundColor: const Color(0xFFE0E5DE), color: farmersAhead<=2? const Color(0xFFEF6C00): const Color(0xFF2E7D32)),
                      const SizedBox(height:2),
                      Text('Status: ${queue?.status.name.toUpperCase() ?? booking.queueStatus.name.toUpperCase()} • ${wait} min', style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ])),
                  ]),
                  const SizedBox(height:8),
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.lightbulb, color: Color(0xFF2E7D32), size:16), const SizedBox(width:6), Expanded(child: Text('${loc.nextAction}: $nextAction', style: const TextStyle(fontSize:11, fontWeight: FontWeight.w600, color: Color(0xFF1B5E20))))])),
                ])),
                const SizedBox(height:12),
                // Capacity warnings
                if ((capacity['warnings'] as List?)?.isNotEmpty == true) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children:[const Icon(Icons.warning_amber, color: Color(0xFFEF6C00)), const SizedBox(width:6), Text(loc.centreCapacity, style: const TextStyle(fontWeight: FontWeight.w700, fontSize:12))]),
                  const SizedBox(height:6),
                  Text('Total ${capacity['total_capacity']} • Used ${capacity['used_capacity']} • Remaining ${capacity['remaining_capacity']} • Queue ${capacity['current_queue']}', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height:6),
                  ...(capacity['warnings'] as List).map((w)=> Padding(padding: const EdgeInsets.symmetric(vertical:2), child: Row(children:[const Icon(Icons.circle, size:6, color: Color(0xFFEF6C00)), const SizedBox(width:6), Expanded(child: Text(w.toString(), style: const TextStyle(fontSize:11, color: Color(0xFFBF360C))))]))),
                ])),
                if ((capacity['warnings'] as List?)?.isNotEmpty == true) const SizedBox(height:12),
                // Documents checklist with Required/Completed/Missing
                AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children:[Text(loc.requiredDocuments, style: const TextStyle(fontWeight: FontWeight.w700)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)), child: Text(loc.centreDocuments, style: TextStyle(fontSize:9, color: Theme.of(context).colorScheme.onSurfaceVariant)))]),
                  const SizedBox(height:8),
                  ...docsList.map((doc){
                    final key = doc['label'] as String;
                    final label = doc['label'] as String;
                    final done = _docsCompleted[key] ?? false;
                    final required = doc['required'] as bool? ?? true;
                    final desc = doc['description'] as String? ?? '';
                    return InkWell(onTap: ()=> setState(()=> _docsCompleted[key]=!done), child: Padding(padding: const EdgeInsets.symmetric(vertical:4), child: Row(children: [
                      Icon(done? Icons.check_box: Icons.check_box_outline_blank, size:20, color: done? const Color(0xFF2E7D32): Colors.grey),
                      const SizedBox(width:8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                        Text(label, style: TextStyle(fontSize:12, decoration: done? TextDecoration.lineThrough: null)),
                        Text('${required? 'Required':'Optional'}${desc.isNotEmpty ? ' • $desc':''}', style: TextStyle(fontSize:10, color: required? Colors.red.shade700: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: done? const Color(0xFFE8F5E9): required? const Color(0xFFFFEBEE): Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: Text(done? 'Completed': required? 'Missing':'Optional', style: TextStyle(fontSize:10, color: done? const Color(0xFF2E7D32): required? Colors.red: Colors.grey))),
                    ])));
                  }),
                  const SizedBox(height:8),
                  Text('${_docsCompleted.values.where((v)=>v).length}/${docsList.length} ready • Bring originals + 1 photocopy. No sensitive docs stored.', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ])),
                const SizedBox(height:12),
                // Procurement + Payment
                if (timeline!=null) AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(loc.procurementStatus, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height:8),
                  ...timeline.map((t)=> Padding(padding: const EdgeInsets.symmetric(vertical:4), child: Row(children: [Icon(t.isCompleted? Icons.check_circle: t.isCurrent? Icons.radio_button_checked: Icons.radio_button_unchecked, size:16, color: t.isCompleted? const Color(0xFF2E7D32): t.isCurrent? const Color(0xFFEF6C00): Colors.grey), SizedBox(width:8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(t.title, style: TextStyle(fontSize:12, fontWeight: t.isCurrent? FontWeight.w700: FontWeight.normal)), Text(t.subtitle, style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant))]))]))),
                  const SizedBox(height:8),
                  if (payment!=null) Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (payment.status.toString().contains('completed')? const Color(0xFFE8F5E9): const Color(0xFFFFF3E0)), borderRadius: BorderRadius.circular(8)), child: Row(children:[Icon(payment.status.toString().contains('completed')? Icons.check_circle: Icons.payments, color: payment.status.toString().contains('completed')? const Color(0xFF2E7D32): const Color(0xFFEF6C00), size:16), const SizedBox(width:6), Expanded(child: Text('Payment: ${payment.status.toString().split('.').last.toUpperCase()} • ₹${payment.totalAmount.toStringAsFixed(0)} • ${payment.transactionId ?? 'Pending'}', style: const TextStyle(fontSize:11)))])),
                ])),
                const SizedBox(height:12),
                // Receipt button if completed
                if (timeline!=null && timeline.any((t)=> t.title=='Completed' && t.isCompleted)) SizedBox(width: double.infinity, child: OutlinedButton.icon(icon: const Icon(Icons.receipt_long), label: Text(loc.viewReceipt), onPressed: ()=> context.push('/receipt?bookingId=${booking.id}'))),
                const SizedBox(height:12),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(icon: Icon(_reminderOn? Icons.notifications_active: Icons.notifications_off), label: Text(_reminderOn? loc.reminderOn: loc.reminderOff), onPressed: ()=> setState(()=> _reminderOn=!_reminderOn))),
                  const SizedBox(width:8),
                  Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.qr_code), label: Text(loc.showToken), onPressed: ()=> context.push('/token'))),
                ]),
                const SizedBox(height:6),
                Text(_reminderOn? 'Reminder: 30 min before slot • Queue movement • Turn approaching — via FCM (mock if no creds)':'Enable reminder for slot updates', textAlign: TextAlign.center, style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]);
            },
          );
        },
      ),
    );
  }
}

const _docs = [
  'Farmer ID (FARM-*)',
  'Aadhaar',
  'Bank passbook (for payment)',
  'Land document (Patta/Chitta) if required',
  'Paddy sample (500g) / commodity sample',
];

class _Row extends StatelessWidget {
  final String label; final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context)=> Padding(padding: const EdgeInsets.symmetric(vertical:2), child: Row(children: [SizedBox(width:90, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize:11))), Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize:12)))]));
}

final _activeBookingProvider = FutureProvider<Booking?>((ref) async {
  final auth = await ref.watch(authRepositoryProvider).getCurrentUser();
  if (auth==null) return null;
  return ref.watch(slotRepositoryProvider).getActiveBooking(auth.id);
});
