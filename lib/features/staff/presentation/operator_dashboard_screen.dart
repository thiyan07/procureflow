import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/config/demo_config.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/mock/mock_database.dart';
import '../../../services/providers.dart';
import '../../../services/api/api_queue_repository.dart';
import '../../../core/network/api_client.dart';

class OperatorDashboardScreen extends ConsumerWidget {
  const OperatorDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref){
    ref.watch(queueRefreshProvider);
    final loc = AppLocalizations.of(context)!;
    if(DemoConfig.useMockBackend){
      final db = MockDatabase.instance;
      final total = db.bookings.length + 340;
      final waiting = db.globalCurrentOrdinal < 27 ? 27 - db.globalCurrentOrdinal : 6;
      return Scaffold(
        appBar: AppBar(title: Text('${loc.operatorDashboard} (Mock)'), actions: [
          IconButton(icon: const Icon(Icons.person_outline), tooltip: loc.profile, onPressed: ()=> context.push('/profile')),
          IconButton(icon: const Icon(Icons.logout), tooltip: loc.logout, onPressed: () async { await ref.read(authRepositoryProvider).logout(); if(context.mounted) context.go('/login'); }),
        ]),
        body: _DashboardBody(total: total, waiting: waiting, processing: 41, completed: 217, paymentPending: 21, avgWait: 31, centreName: 'Bhavani Procurement Centre • Operator'),
      );
    }
    final dashboardAsync = ref.watch(_dashboardProvider);
    return Scaffold(
      appBar: AppBar(title: Text(loc.operatorDashboard), actions: [
        IconButton(icon: const Icon(Icons.person_outline), tooltip: loc.profile, onPressed: ()=> context.push('/profile')),
        IconButton(icon: const Icon(Icons.refresh), onPressed: ()=> ref.invalidate(_dashboardProvider)),
        IconButton(icon: const Icon(Icons.logout), tooltip: loc.logout, onPressed: () async { await ref.read(authRepositoryProvider).logout(); if(context.mounted) context.go('/login'); }),
      ]),
      body: dashboardAsync.when(
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> ErrorState(message: e.toString(), onRetry: ()=> ref.invalidate(_dashboardProvider)),
        data: (d){
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_dashboardProvider),
            child: _DashboardBody(
              total: d['today_farmers'] as int? ?? 0,
              waiting: d['waiting'] as int? ?? 0,
              processing: d['processing'] as int? ?? 0,
              completed: d['completed'] as int? ?? 0,
              paymentPending: d['payment_pending'] as int? ?? 0,
              avgWait: d['avg_wait_minutes'] as int? ?? 0,
              centreName: (d['centre_name'] as String? ?? 'Bhavani') + ' • Operator',
            ),
          );
        },
      ),
    );
  }
}

final _dashboardProvider = FutureProvider<Map<String,dynamic>>((ref) async {
  ref.watch(queueRefreshProvider);
  final repo = ref.read(queueRepositoryProvider) as ApiQueueRepository;
  return repo.getDashboard('c1');
});
final _peakProvider = FutureProvider<Map<String,dynamic>>((ref) async {
  final c = ref.read(apiClientProvider);
  return c.get('/api/v1/analytics/management');
});
final _capacityProvider = FutureProvider<Map<String,dynamic>>((ref) async {
  final c = ref.read(apiClientProvider);
  return c.get('/api/v1/centres/c1/capacity');
});
final _awardOptimiserProvider = FutureProvider.family<Map<String,dynamic>, String>((ref, centreId) async {
  final c = ref.read(apiClientProvider);
  final today = DateTime.now().toIso8601String().split('T').first;
  try {
    return await c.post('/api/v1/analytics/award-optimise', body: {'centre_id': centreId, 'date': today});
  } catch (e) {
    // Mock fallback for DemoConfig or offline — deterministic
    if (DemoConfig.useMockBackend) {
      return {
        'suggested_centre': 'c2',
        'reason': 'c1 85% booked, c2 40% — balance load',
        'triggered': true,
        'occupancy': 0.85,
        'total_farmers': 87,
        'distribution': [
          {'centre_id': 'c1', 'centre_name': 'Bhavani', 'current_load': 87, 'capacity': 120, 'occupancy': 0.85, 'suggested_add': -10},
          {'centre_id': 'c2', 'centre_name': 'Perundurai', 'current_load': 48, 'capacity': 120, 'occupancy': 0.4, 'suggested_add': 10},
          {'centre_id': 'c3', 'centre_name': 'Sathyamangalam', 'current_load': 72, 'capacity': 120, 'occupancy': 0.6, 'suggested_add': 0},
          {'centre_id': 'c4', 'centre_name': 'Gobichettipalayam', 'current_load': 36, 'capacity': 120, 'occupancy': 0.3, 'suggested_add': 0},
        ],
      };
    }
    return {};
  }
});

class _DashboardBody extends ConsumerWidget {
  final int total, waiting, processing, completed, paymentPending, avgWait;
  final String centreName;
  const _DashboardBody({required this.total, required this.waiting, required this.processing, required this.completed, required this.paymentPending, required this.avgWait, required this.centreName});
  @override
  Widget build(BuildContext context, WidgetRef ref){
    final peakAsync = ref.watch(_peakProvider);
    final capAsync = ref.watch(_capacityProvider);
    return ListView(padding: const EdgeInsets.all(16), children:[
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)), child: Row(children:[
          const Icon(Icons.verified_user, color: Color(0xFF2E7D32)),
          const SizedBox(width:8),
          Expanded(child: Text(centreName, style: const TextStyle(fontWeight: FontWeight.w600))),
          Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:4), decoration: BoxDecoration(color: const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(20)), child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize:10))),
        ])),
        const SizedBox(height:12),
        GridView.count(crossAxisCount:2, shrinkWrap:true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing:12, crossAxisSpacing:12, childAspectRatio:1.4, children:[
          _StatCard(title: "Today's Farmers", value: "$total", subtitle: "live", color: const Color(0xFF1565C0)),
          _StatCard(title: "Waiting", value: "$waiting", subtitle: "Queue", color: const Color(0xFFEF6C00)),
          _StatCard(title: "Processing", value: "$processing", subtitle: "At counters", color: const Color(0xFF6A1B9A)),
          _StatCard(title: "Completed", value: "$completed", subtitle: "Today", color: const Color(0xFF2E7D32)),
          _StatCard(title: "Payment Pending", value: "$paymentPending", subtitle: "To process", color: const Color(0xFFC62828)),
          _StatCard(title: "Avg Wait", value: "$avgWait min", subtitle: "Per farmer", color: const Color(0xFF00838F)),
        ]),
        const SizedBox(height:12),
        peakAsync.when(
          loading: ()=> const AppCard(child: LinearProgressIndicator()),
          error: (e,s)=> AppCard(child: Text('Peak: 10 AM - 12 PM (fallback)')),
          data: (peak){
            final peaks = (peak['peak_periods'] as List?) ?? [];
            final cap = capAsync.value;
            final occ = cap != null ? (cap['occupancy'] as double? ?? 0.0) : 0.0;
            final peakText = peaks.isNotEmpty ? '${peaks[0]['time']} • ${peaks[0]['total_booked']} bookings' : '10 AM - 12 PM • High load expected';
            final peakVal = occ > 0 ? occ : 0.68;
            return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              const Text('Peak Period', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height:4),
              Text(peakText, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize:12)),
              const SizedBox(height:8),
              LinearProgressIndicator(value: peakVal.clamp(0,1), color: peakVal>0.7 ? const Color(0xFFEF6C00): const Color(0xFF2E7D32)),
              if (cap != null) Padding(padding: const EdgeInsets.only(top:4), child: Text('Capacity ${(occ*100).toInt()}% • ${cap['remaining_capacity']} slots left', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant))),
            ]));
          },
        ),
        // Award Optimiser light — deterministic, shown when total>50 or occupancy>0.85
        Builder(builder: (context){
          final cap = capAsync.value;
          final occ = cap != null ? (cap['occupancy'] as double? ?? 0.0) : 0.0;
          final show = total > 50 || occ > 0.85;
          if (!show) return const SizedBox.shrink();
          return Column(children:[
            const SizedBox(height:12),
            _AwardOptimiserCard(total: total, occupancy: occ, centreId: 'c1'),
          ]);
        }),
        const SizedBox(height:12),
        ElevatedButton.icon(icon: const Icon(Icons.groups), label: const Text("VIEW TODAY'S QUEUE"), onPressed: ()=> context.push('/operator/queue')),
        const SizedBox(height:8),
        OutlinedButton.icon(icon: const Icon(Icons.analytics_outlined), label: const Text('ANALYTICS'), onPressed: ()=> context.push('/analytics')),
        const SizedBox(height:12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text('Centre Controls', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height:8),
          Text('Adjust counters, capacity, or close centre — affects scheduler safely', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          SizedBox(height:12),
        ])),
        _CentreControlsCard(),
       ]);
  }
}
class _CentreControlsCard extends ConsumerStatefulWidget {
  const _CentreControlsCard();
  @override
  ConsumerState<_CentreControlsCard> createState()=> _CentreControlsCardState();
}
class _CentreControlsCardState extends ConsumerState<_CentreControlsCard>{
  int _counters=3;
  int _capacity=20;
  String _status='Open';
  bool _saving=false;
  Future<void> _save() async{
    setState(()=> _saving=true);
    try{
      await ref.read(apiClientProvider).patch('/api/v1/centres/c1', body:{'active_counters': _counters, 'slot_capacity': _capacity, 'status': _status});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Centre updated: counters $_counters, capacity $_capacity, $_status')));
    }catch(e){ if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally{ if (mounted) setState(()=> _saving=false); }
  }
  @override
  Widget build(BuildContext context)=> Column(children:[
    Row(children:[
      Expanded(child: DropdownButtonFormField<int>(value:_counters, icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1A1C19)), decoration: const InputDecoration(labelText:'Active counters'), items: List.generate(6,(i)=> DropdownMenuItem(value:i, child: Text('$i'))), onChanged:(v)=> setState(()=> _counters=v!))),
      const SizedBox(width:12),
      Expanded(child: DropdownButtonFormField<int>(value:_capacity, icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1A1C19)), decoration: const InputDecoration(labelText:'Slot capacity'), items: [10,15,20,25,30].map((e)=> DropdownMenuItem(value:e, child: Text('$e'))).toList(), onChanged:(v)=> setState(()=> _capacity=v!))),
    ]),
    const SizedBox(height:12),
    DropdownButtonFormField<String>(value:_status, icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1A1C19)), decoration: const InputDecoration(labelText:'Centre status'), items: const [DropdownMenuItem(value:'Open', child: Text('OPEN')), DropdownMenuItem(value:'Busy', child: Text('BUSY')), DropdownMenuItem(value:'Closed', child: Text('CLOSED — blocks new bookings'))], onChanged:(v)=> setState(()=> _status=v!)),
    const SizedBox(height:12),
    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving?null:_save, icon: _saving? const SizedBox(width:14,height:14, child:CircularProgressIndicator(strokeWidth:2)): const Icon(Icons.save), label: const Text('Save Centre Settings'))),
    const SizedBox(height:6),
    Text('CLOSED prevents new bookings and explains why; active counters affect wait estimation.', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
  ]);
}

class _AwardOptimiserCard extends ConsumerWidget {
  final int total;
  final double occupancy;
  final String centreId;
  const _AwardOptimiserCard({required this.total, required this.occupancy, required this.centreId});
  @override
  Widget build(BuildContext context, WidgetRef ref){
    final async = ref.watch(_awardOptimiserProvider(centreId));
    return async.when(
      loading: ()=> const AppCard(child: LinearProgressIndicator()),
      error: (e,s)=> AppCard(child: Text('Award Optimiser: $e', style: const TextStyle(fontSize:12))),
      data: (data){
        if (data.isEmpty) return const SizedBox.shrink();
        final suggested = data['suggested_centre'] as String? ?? 'c2';
        final reason = data['reason'] as String? ?? 'Load balanced';
        final dist = (data['distribution'] as List?)?.cast<Map<String,dynamic>>() ?? [];
        final triggered = data['triggered'] as bool? ?? false;
        final centreNames = {'c1':'Bhavani','c2':'Perundurai','c3':'Sathyamangalam','c4':'Gobichettipalayam'};
        return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Row(children:[
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.balance, color: Color(0xFFEF6C00), size:18)),
            const SizedBox(width:8),
            const Expanded(child: Text('Award Optimiser — Load Balancing', style: TextStyle(fontWeight: FontWeight.w800, fontSize:13))),
            Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: triggered? const Color(0xFFEF6C00): const Color(0xFF2E7D32), borderRadius: BorderRadius.circular(10)), child: Text(triggered?'REBALANCE':'OK', style: const TextStyle(color: Colors.white, fontSize:10, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height:8),
          Text(reason, style: TextStyle(fontSize:12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height:10),
          ...dist.map((d){
            final cid = d['centre_id'] as String? ?? '';
            final load = d['current_load'] as int? ?? 0;
            final cap = d['capacity'] as int? ?? 0;
            final occ = (d['occupancy'] as num? ?? 0).toDouble();
            final add = d['suggested_add'] as int? ?? 0;
            final isSuggested = cid == suggested && triggered;
            return Padding(padding: const EdgeInsets.symmetric(vertical:3), child: Row(children:[
              SizedBox(width:48, child: Text(cid, style: TextStyle(fontSize:11, fontWeight: isSuggested? FontWeight.w800: FontWeight.w600, color: isSuggested? const Color(0xFF2E7D32): null))),
              SizedBox(width:70, child: Text(centreNames[cid]??cid, style: const TextStyle(fontSize:11))),
              Expanded(child: LinearProgressIndicator(value: cap>0? (load/cap).clamp(0,1): occ, minHeight:6, color: occ>0.85? Colors.red: occ>0.7? const Color(0xFFEF6C00): const Color(0xFF2E7D32))),
              const SizedBox(width:6),
              SizedBox(width:54, child: Text('$load/$cap', style: const TextStyle(fontSize:11))),
              if (add != 0) Container(padding: const EdgeInsets.symmetric(horizontal:5,vertical:2), decoration: BoxDecoration(color: add>0? const Color(0xFFE8F5E9): const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(6)), child: Text(add>0? '+$add':'$add', style: TextStyle(fontSize:10, fontWeight: FontWeight.w700, color: add>0? const Color(0xFF2E7D32): Colors.red))),
            ]));
          }),
          const SizedBox(height:10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            icon: const Icon(Icons.swap_horiz, size:18),
            label: Text('View ${centreNames[suggested] ?? suggested} slots'),
            onPressed: (){
              // Prefer slots view for alternative centre; also allow queue view
              context.push('/slots?centreId=$suggested');
            },
          )),
          TextButton(
            onPressed: ()=> context.push('/operator/queue?centreId=$suggested'),
            child: Text('View ${centreNames[suggested] ?? suggested} queue', style: const TextStyle(fontSize:12)),
          ),
          Text('Deterministic • uses Slot booked/capacity • light rebalancing (max 10)',
            style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]));
      },
    );
  }
}

class _StatCard extends StatelessWidget{
  final String title; final String value; final String subtitle; final Color color;
  const _StatCard({required this.title, required this.value, required this.subtitle, required this.color});
  @override
  Widget build(BuildContext context)=> AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
    Container(width:36,height:4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
    const SizedBox(height:8),
    Text(title, style: const TextStyle(fontSize:11, color: Color(0xFF5A5F5A), fontWeight: FontWeight.w600)),
    Text(value, style: TextStyle(fontSize:22, fontWeight: FontWeight.w800, color: color)),
    Text(subtitle, style: const TextStyle(fontSize:11, color: Color(0xFF5A5F5A))),
  ]));
}
