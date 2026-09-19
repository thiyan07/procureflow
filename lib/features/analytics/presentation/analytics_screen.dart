import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';
import '../../../core/network/api_client.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState()=> _AnalyticsScreenState();
}
class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>{
  String _centreId='c1';
  @override
  Widget build(BuildContext context){
    final loadAsync = ref.watch(_loadProvider(_centreId));
    final mgmtAsync = ref.watch(_mgmtProvider);
    final demandAsync = ref.watch(_demandProvider(_centreId));
    final anomalyAsync = ref.watch(_anomalyProvider(_centreId));
    final capacityAsync = ref.watch(_capacityProvider(_centreId));
    final alertsAsync = ref.watch(_alertsProvider(_centreId));
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(padding: const EdgeInsets.all(16), children:[
        // Centre filter
        DropdownButtonFormField<String>(value:_centreId, decoration: const InputDecoration(labelText:'Centre'), items: const [DropdownMenuItem(value:'c1', child: Text('Bhavani RM')), DropdownMenuItem(value:'c2', child: Text('Perundurai RM')), DropdownMenuItem(value:'c3', child: Text('Sathyamangalam RM')), DropdownMenuItem(value:'c4', child: Text('Gobichettipalayam RM'))], onChanged:(v)=> setState(()=> _centreId=v!)),
        const SizedBox(height:12),
        mgmtAsync.when(
          loading: ()=> const Center(child: CircularProgressIndicator()),
          error: (e,s)=> ErrorState(message: e.toString()),
          data: (mgmt){
            final centres = (mgmt['centres'] as List?) ?? [];
            final totalFarmers = centres.fold(0, (a,e)=> a + (e['total_bookings'] as int? ?? 0));
            final completed = centres.fold(0, (a,e)=> a + (e['completed'] as int? ?? 0));
            return Column(children:[
              Row(children:[
                Expanded(child: _Kpi(title:'Total Farmers', value:'$totalFarmers', icon: Icons.groups)),
                const SizedBox(width:12),
                Expanded(child: _Kpi(title:'Completed', value:'$completed', icon: Icons.check_circle)),
              ]),
              const SizedBox(height:12),
              Row(children:[
                Expanded(child: _Kpi(title:'Active Centres', value:'${centres.length}', icon: Icons.store)),
                const SizedBox(width:12),
                Expanded(child: Consumer(builder: (c, ref, _){
                  final opAsync = ref.watch(_operatorProvider(_centreId));
                  return opAsync.when(
                    loading: ()=> const _Kpi(title:'Avg Wait', value:'--', icon: Icons.schedule),
                    error: (_,__)=> const _Kpi(title:'Avg Wait', value:'--', icon: Icons.schedule),
                    data: (op)=> _Kpi(title:'Avg Wait', value:'${op['avg_wait'] ?? 5} min', icon: Icons.schedule),
                  );
                })),
              ]),
            ]);
          },
        ),
        const SizedBox(height:16),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          const Text('Centre Load Prediction (Tomorrow)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height:12),
          SizedBox(height:160, child: loadAsync.when(
            loading: ()=> const Center(child: CircularProgressIndicator()),
            error: (e,s)=> Text('Error $e'),
            data: (list){
              final peakCandidates = list.where((e)=> e.isPeak).toList();
              final peak = peakCandidates.isNotEmpty ? peakCandidates.first : (list.isNotEmpty ? list.reduce((a,b)=> a.expectedFarmers > b.expectedFarmers ? a : b) : null);
              return Column(children:[
                Expanded(child: BarChart(BarChartData(
                  barGroups: list.asMap().entries.map((e)=> BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.expectedFarmers.toDouble(), color: e.value.isPeak? const Color(0xFFEF6C00): const Color(0xFF2E7D32), width:12)])).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles:true, getTitlesWidget: (v,_){
                      const labels = ['8-9','9-10','10-11','11-12','13-14','14-15'];
                      if (v.toInt() < labels.length) return Text(labels[v.toInt()], style: const TextStyle(fontSize:9));
                      return const Text('');
                    })),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles:true, reservedSize:28)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles:false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles:false)),
                  ),
                  gridData: const FlGridData(show:false),
                  borderData: FlBorderData(show:false),
                ))),
                const SizedBox(height:6),
                Text(peak != null ? 'Peak ${peak.slotLabel} • ${peak.expectedFarmers} expected • Lower load = recommended' : 'No peak — lower load = recommended', style: const TextStyle(fontSize:11, color: Colors.black54)),
              ]);
            },
          )),
        ])),
        const SizedBox(height:12),
        capacityAsync.when(
          loading: ()=> const SizedBox(),
          error: (_,__)=> const SizedBox(),
          data: (cap){
            final occ = (cap['occupancy'] as double? ?? 0.68);
            final warn = (cap['warnings'] as List?) ?? [];
            return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              const Text('Centre Capacity', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height:8),
              LinearProgressIndicator(value: occ, minHeight:8, color: occ>0.85? Colors.red: occ>0.7? const Color(0xFFEF6C00): const Color(0xFF2E7D32)),
              const SizedBox(height:4),
              Text('${(occ*100).toInt()}% today • ${cap['remaining_capacity']} slots remaining • Queue ${cap['current_queue']} • Counters ${cap['active_counters']}', style: const TextStyle(fontSize:11, color: Colors.black54)),
              if (warn.isNotEmpty) ...[
                const SizedBox(height:6),
                ...warn.map((w)=> Padding(padding: const EdgeInsets.symmetric(vertical:2), child: Row(children:[const Icon(Icons.warning, size:12, color: Color(0xFFEF6C00)), const SizedBox(width:4), Expanded(child: Text(w.toString(), style: const TextStyle(fontSize:11, color: Color(0xFFBF360C))))]))),
              ],
            ]));
          },
        ),
        const SizedBox(height:12),
        alertsAsync.when(
          loading: ()=> const SizedBox(),
          error: (_,__)=> const SizedBox(),
          data: (data){
            final alerts = (data['alerts'] as List?) ?? [];
            return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Row(children:[const Icon(Icons.campaign, color: Color(0xFFEF6C00), size:18), const SizedBox(width:6), const Text('Congestion Alerts (Rule-based)', style: TextStyle(fontWeight: FontWeight.w700, fontSize:13))]),
              const SizedBox(height:8),
              ...alerts.map((a){
                final m=a as Map; final sev=m['severity'] as String? ?? 'info';
                final col = sev=='high'? Colors.red: sev=='medium'? const Color(0xFFEF6C00): Colors.grey;
                return Padding(padding: const EdgeInsets.symmetric(vertical:4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[
                  Icon(sev=='high'? Icons.error: sev=='medium'? Icons.warning: Icons.info, color: col, size:16),
                  const SizedBox(width:6),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                    Text(m['message']?.toString()??'', style: TextStyle(fontSize:12, fontWeight: FontWeight.w600, color: col)),
                    Text(m['action']?.toString()??'', style: const TextStyle(fontSize:11, color: Colors.black54)),
                  ])),
                ]));
              }),
              const SizedBox(height:4),
              Text('Not ML — deterministic thresholds queue>15, wait>30, capacity>80%, counters<2', style: const TextStyle(fontSize:10, color: Colors.black45)),
            ]));
          },
        ),
        const SizedBox(height:12),
        demandAsync.when(
          loading: ()=> const SizedBox(),
          error: (_,__)=> const SizedBox(),
          data: (data){
            final forecast = (data['forecast'] as List?) ?? [];
            return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              const Text('Demand Forecast (per centre, 7 days)', style: TextStyle(fontWeight: FontWeight.w700, fontSize:13)),
              const SizedBox(height:4),
              const Text('Baseline fallback clearly marked if insufficient history', style: TextStyle(fontSize:11, color: Colors.black54)),
              const SizedBox(height:8),
              ...forecast.take(5).map((e){
                final m=e as Map; final conf=m['confidence'] as String? ?? 'low';
                return Padding(padding: const EdgeInsets.symmetric(vertical:3), child: Row(children:[
                  SizedBox(width:90, child: Text(m['date']?.toString()??'', style: const TextStyle(fontSize:11))),
                  Expanded(child: LinearProgressIndicator(value: ((m['predicted_bookings'] as int? ?? 18)/30).clamp(0,1), minHeight:6, color: conf=='low'? Colors.grey: const Color(0xFF2E7D32))),
                  const SizedBox(width:6),
                  Text('${m['predicted_bookings']} ${conf=='low'? '(fallback)':''}', style: TextStyle(fontSize:11, color: conf=='low'? Colors.grey: Colors.black87)),
                ]));
              }),
              const SizedBox(height:4),
              Text('Model: ${data['model_info']??''}', style: const TextStyle(fontSize:10, color: Colors.black45)),
            ]));
          },
        ),
        const SizedBox(height:12),
        anomalyAsync.when(
          loading: ()=> const SizedBox(),
          error: (_,__)=> const SizedBox(),
          data: (data){
            final anomalies = (data['anomalies'] as List?) ?? [];
            return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              const Text('Anomaly Detection (Lightweight)', style: TextStyle(fontWeight: FontWeight.w700, fontSize:13)),
              const SizedBox(height:8),
              ...anomalies.map((a){
                final m=a as Map; final sev=m['severity'] as String? ?? 'info';
                final col = sev=='high'? Colors.red: sev=='medium'? const Color(0xFFEF6C00): Colors.grey;
                return Padding(padding: const EdgeInsets.symmetric(vertical:4), child: Row(children:[
                  Icon(sev=='high'? Icons.bug_report: Icons.check_circle, color: col, size:16),
                  const SizedBox(width:6),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                    Text(m['message']?.toString()??'', style: TextStyle(fontSize:12, color: col)),
                    Text(m['reason']?.toString()??'', style: const TextStyle(fontSize:11, color: Colors.black54)),
                  ])),
                ]));
              }),
              const SizedBox(height:4),
              const Text('No heavy ML — rule-based queue/spike/capacity/delay', style: TextStyle(fontSize:10, color: Colors.black45)),
            ]));
          },
        ),
        const SizedBox(height:12),
        OutlinedButton.icon(icon: const Icon(Icons.download), label: const Text('Export CSV (Bookings last 7 days)'), onPressed: () async {
          final repo = ref.read(apiClientProvider);
          try{
            final data = await repo.get('/api/v1/analytics/management');
            final trend = (data['demand_trend_7d'] as List?) ?? [];
            final csv = StringBuffer('date,bookings\n');
            for (final e in trend){ final m = e as Map; csv.writeln('${m['date']},${m['bookings']}'); }
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV ready: ${csv.toString().split('\n').take(3).join(' | ')}... • Copy from /management'))); 
          }catch(e){ if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
        }),
        const SizedBox(height:6),
        const Text('Reports: Daily centre / Procurement summary / Queue / Payment / Commodity via CSV. No complex BI.', style: TextStyle(fontSize:11, color: Colors.black45)),
      ]),
    );
  }
}
class _Kpi extends StatelessWidget{
  final String title; final String value; final IconData icon;
  const _Kpi({required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context)=> AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
    Icon(icon, color: const Color(0xFF2E7D32), size:20),
    const SizedBox(height:6),
    Text(title, style: const TextStyle(fontSize:11, color: Colors.black54)),
    Text(value, style: const TextStyle(fontSize:20, fontWeight: FontWeight.w800)),
  ]));
}
final _loadProvider = FutureProvider.family((ref, String centreId)=> ref.watch(aiRepositoryProvider).predictCentreLoad(centreId, DateTime.now().add(const Duration(days:1))));
final _mgmtProvider = FutureProvider((ref) async {
  final c = ref.watch(apiClientProvider);
  return c.get('/api/v1/analytics/management');
});
final _demandProvider = FutureProvider.family((ref, String centreId) async {
  final c = ref.watch(apiClientProvider);
  return c.get('/api/v1/ai/demand-forecast', query: {'centre_id': centreId, 'days': 7});
});
final _anomalyProvider = FutureProvider.family((ref, String centreId) async {
  final c = ref.watch(apiClientProvider);
  return c.get('/api/v1/ai/anomalies/$centreId');
});
final _capacityProvider = FutureProvider.family((ref, String centreId) async {
  final c = ref.watch(apiClientProvider);
  final today = DateTime.now().toIso8601String().split('T').first;
  return c.get('/api/v1/centres/$centreId/capacity', query: {'target_date': today});
});
final _alertsProvider = FutureProvider.family((ref, String centreId) async {
  final c = ref.watch(apiClientProvider);
  return c.get('/api/v1/centres/$centreId/alerts');
});
final _operatorProvider = FutureProvider.family((ref, String centreId) async {
  final c = ref.watch(apiClientProvider);
  return c.get('/api/v1/analytics/operator/$centreId');
});
