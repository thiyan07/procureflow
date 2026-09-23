import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../l10n/app_localizations.dart';
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
    final loc = AppLocalizations.of(context)!;
    final loadAsync = ref.watch(_loadProvider(_centreId));
    final mgmtAsync = ref.watch(_mgmtProvider);
    final demandAsync = ref.watch(_demandProvider(_centreId));
    final anomalyAsync = ref.watch(_anomalyProvider(_centreId));
    final capacityAsync = ref.watch(_capacityProvider(_centreId));
    final alertsAsync = ref.watch(_alertsProvider(_centreId));
    final p90Async = ref.watch(_p90Provider((_centreId, 30)));
    final unifiedAsync = ref.watch(_analyticsAnomaliesProvider(_centreId));
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(padding: const EdgeInsets.all(16), children:[
        // Centre filter
        DropdownButtonFormField<String>(value:_centreId, decoration: InputDecoration(labelText: loc.centreStatus), items: const [DropdownMenuItem(value:'c1', child: Text('Bhavani RM')), DropdownMenuItem(value:'c2', child: Text('Perundurai RM')), DropdownMenuItem(value:'c3', child: Text('Sathyamangalam RM')), DropdownMenuItem(value:'c4', child: Text('Gobichettipalayam RM'))], onChanged:(v)=> setState(()=> _centreId=v!)),
        const SizedBox(height:12),
        // P90 booking→payment cycle analytics
        p90Async.when(
          loading: ()=> const AppCard(child: Center(child: CircularProgressIndicator())),
          error: (e,s)=> AppCard(child: Text('P90 error: $e', style: const TextStyle(fontSize:12, color: Colors.red))),
          data: (p90){
            final p50 = (p90['p50'] as num?)?.toDouble() ?? 5.1;
            final p90v = (p90['p90'] as num?)?.toDouble() ?? 7.2;
            final avgWait = (p90['avg_wait'] as num?)?.toDouble() ?? 5.8;
            final payDelay = (p90['payment_delay_avg'] as num?)?.toDouble() ?? 1.4;
            final noShow = (p90['no_show_rate'] as num?)?.toDouble() ?? 0.084;
            final target = (p90['target_days'] as num?)?.toDouble() ?? 8.0;
            final total = p90['total_bookings'] ?? 0;
            final isSynthetic = p90['is_synthetic'] == true;
            final savings = (p90['savings_pct'] as num?)?.toDouble() ?? 12.4;
            final progress = (p90v / target).clamp(0.0, 1.0);
            final col = p90v <= target ? const Color(0xFF2E7D32) : p90v <= target*1.1 ? const Color(0xFFEF6C00) : Colors.red;
            return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Row(children:[
                const Icon(Icons.timer_outlined, color: Color(0xFF2E7D32), size:18),
                const SizedBox(width:6),
                const Text('P90 Cycle (Booking → Payment)', style: TextStyle(fontWeight: FontWeight.w700, fontSize:13)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:4), decoration: BoxDecoration(color: isSynthetic? Colors.amber.withValues(alpha:0.2): const Color(0xFF2E7D32).withValues(alpha:0.12), borderRadius: BorderRadius.circular(12)), child: Text(isSynthetic? 'Synthetic • 7.2d • 12.4% savings': '${savings.toStringAsFixed(1)}% savings', style: TextStyle(fontSize:10, fontWeight: FontWeight.w700, color: isSynthetic? const Color(0xFFBF360C): const Color(0xFF2E7D32)))),
              ]),
              const SizedBox(height:10),
              Row(children:[
                Expanded(child: _P90Metric(label:'P50', value:'${p50.toStringAsFixed(1)}d', sub:'median', icon: Icons.show_chart)),
                Expanded(child: _P90Metric(label:'P90', value:'${p90v.toStringAsFixed(1)}d', sub:'target ${target.toStringAsFixed(1)}d', icon: Icons.speed, highlight: true)),
                Expanded(child: _P90Metric(label:'Avg Wait', value:'${avgWait.toStringAsFixed(1)}d', sub:'booking→pay', icon: Icons.schedule)),
                Expanded(child: _P90Metric(label:'Payment Delay', value:'${payDelay.toStringAsFixed(1)}d', sub:'proc→pay', icon: Icons.payments)),
                Expanded(child: _P90Metric(label:'No-show', value:'${(noShow*100).toStringAsFixed(1)}%', sub:'$total bookings', icon: Icons.person_off)),
              ]),
              const SizedBox(height:10),
              Row(children:[
                const Text('P90 vs target', style: TextStyle(fontSize:11, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${p90v.toStringAsFixed(1)} / ${target.toStringAsFixed(1)}d', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
              const SizedBox(height:4),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, minHeight:8, backgroundColor: Colors.grey.shade200, color: col)),
              const SizedBox(height:4),
              Text(isSynthetic? 'Synthetic fallback — insufficient history (<5 cycles). Real DB: booking.created_at → payment.payment_date / procurement.completed': 'Real DB • ${p90['durations_count']} cycles • ${p90['note']??''}', style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]));
          },
        ),
        const SizedBox(height:12),
        // --- Demand Forecast (7 days) deterministic moving_avg_30d ---
        demandAsync.when(
          loading: ()=> const AppCard(child: Center(child: CircularProgressIndicator())),
          error: (e,s)=> AppCard(child: Text('Forecast error: $e', style: const TextStyle(fontSize:11, color: Colors.red))),
          data: (data){
            final forecast = (data['forecast'] as List?) ?? [];
            final total = data['total_predicted'] ?? forecast.fold(0, (a,e)=> a + ((e as Map)['predicted_bookings'] as int? ?? 0));
            final trend = (data['trend'] as String?) ?? 'stable';
            final method = data['method'] ?? 'moving_avg_30d';
            final isSynthetic = data['is_synthetic'] == true;
            final p50 = (data['p50'] as num?)?.toDouble();
            final p90v = (data['p90'] as num?)?.toDouble();
            Color trendCol;
            IconData trendIcon;
            if (trend == 'rising') { trendCol = Colors.red; trendIcon = Icons.trending_up; }
            else if (trend == 'falling') { trendCol = const Color(0xFF2E7D32); trendIcon = Icons.trending_down; }
            else { trendCol = const Color(0xFF616161); trendIcon = Icons.trending_flat; }
            final double maxY = forecast.isEmpty ? 10 : (forecast.map((e)=> ((e as Map)['predicted_bookings'] as num?)?.toDouble() ?? 0).reduce((a,b)=> a>b?a:b) + 4);
            return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Row(children:[
                const Icon(Icons.insights, color: Color(0xFF2E7D32), size:18),
                const SizedBox(width:6),
                const Text('Demand Forecast (7D)', style: TextStyle(fontWeight: FontWeight.w700, fontSize:13)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:4), decoration: BoxDecoration(color: trendCol.withValues(alpha:0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: trendCol.withValues(alpha:0.3))), child: Row(mainAxisSize: MainAxisSize.min, children:[Icon(trendIcon, size:12, color: trendCol), const SizedBox(width:4), Text(trend, style: TextStyle(fontSize:10, fontWeight: FontWeight.w700, color: trendCol))])),
                if (isSynthetic) ...[
                  const SizedBox(width:6),
                  Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:3), decoration: BoxDecoration(color: Colors.amber.withValues(alpha:0.2), borderRadius: BorderRadius.circular(8)), child: const Text('Synthetic fallback', style: TextStyle(fontSize:9, fontWeight: FontWeight.w700, color: Color(0xFFBF360C)))),
                ],
              ]),
              const SizedBox(height:6),
              Row(children:[
                Text('Total $total • $method', style: TextStyle(fontSize:11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Spacer(),
                if (p50 != null && p90v != null) Text('p50 ${p50.toStringAsFixed(1)} • p90 ${p90v.toStringAsFixed(1)}', style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
              const SizedBox(height:10),
              // Small bar chart using fl_chart
              if (forecast.isNotEmpty) SizedBox(
                height: 90,
                child: BarChart(BarChartData(
                  maxY: maxY,
                  barGroups: forecast.asMap().entries.map((e){
                    final m = e.value as Map;
                    final v = ((m['predicted_bookings'] as num?) ?? 0).toDouble();
                    final col = isSynthetic ? Colors.grey : const Color(0xFF2E7D32);
                    return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: v, color: col, width: 14, borderRadius: BorderRadius.circular(3))]);
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles:true, getTitlesWidget: (val, meta){
                      final idx = val.toInt();
                      if (idx < forecast.length) {
                        final m = forecast[idx] as Map;
                        final wd = (m['weekday'] as String?) ?? (m['date'] as String).substring(5,10);
                        return Padding(padding: const EdgeInsets.only(top:4), child: Text(wd, style: const TextStyle(fontSize:9, fontWeight: FontWeight.w600)));
                      }
                      return const Text('');
                    }, reservedSize: 18)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles:true, reservedSize: 28, interval: 5, getTitlesWidget: (v,m)=> Text(v.toInt().toString(), style: const TextStyle(fontSize:9)))),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles:false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles:false)),
                  ),
                  gridData: const FlGridData(show:false),
                  borderData: FlBorderData(show:false),
                )),
              ),
              const SizedBox(height:8),
              // Horizontal chips row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: forecast.map((e){
                  final m = e as Map;
                  final dateStr = (m['date'] as String?) ?? '';
                  final wd = (m['weekday'] as String?) ?? '';
                  final pred = m['predicted_bookings'] ?? 0;
                  final low = m['confidence_low'] ?? 0;
                  final high = m['confidence_high'] ?? 0;
                  final wavg = (m['weekday_avg'] as num?)?.toDouble() ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(right:8),
                    padding: const EdgeInsets.symmetric(horizontal:10, vertical:6),
                    decoration: BoxDecoration(color: isSynthetic? Colors.amber.withValues(alpha:0.12): const Color(0xFF2E7D32).withValues(alpha:0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: isSynthetic? const Color(0xFFBF360C).withValues(alpha:0.2): const Color(0xFF2E7D32).withValues(alpha:0.2))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                      Text('$wd • ${dateStr.substring(5)}', style: const TextStyle(fontSize:10, fontWeight: FontWeight.w700)),
                      const SizedBox(height:2),
                      Text('$pred  [$low-$high]', style: TextStyle(fontSize:11, fontWeight: FontWeight.w800, color: isSynthetic? const Color(0xFFBF360C): const Color(0xFF2E7D32))),
                      Text('avg ${wavg.toStringAsFixed(1)}', style: TextStyle(fontSize:9, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ]),
                  );
                }).toList()),
              ),
              const SizedBox(height:6),
              Text(isSynthetic ? 'Synthetic fallback — slot capacity*0.6 as base (deterministic, no ML)' : 'Deterministic $method • weekday avg 30d • confidence ±20%', style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (data['note'] != null) Padding(padding: const EdgeInsets.only(top:2), child: Text(data['note'].toString(), style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant))),
            ]));
          },
        ),
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
                Text(peak != null ? 'Peak ${peak.slotLabel} • ${peak.expectedFarmers} expected • Lower load = recommended' : 'No peak — lower load = recommended', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]);
            },
          )),
        ])),
        const SizedBox(height:12),
        // --- Unified anomalies / capacity / congestion via new endpoint GET /api/v1/analytics/anomalies?centre_id=c1 ---
        unifiedAsync.when(
          loading: ()=> const AppCard(child: Center(child: CircularProgressIndicator())),
          error: (e,s)=> AppCard(child: Text('Unified analytics error: $e', style: const TextStyle(fontSize:11, color: Colors.red))),
          data: (data){
            final capacityWarnings = (data['capacityWarnings'] as List?) ?? [];
            final congestion = (data['congestion'] as Map?) ?? {};
            final anomalies = (data['anomalies'] as List?) ?? [];
            final thresholds = (data['thresholds'] as Map?) ?? {};
            final occ = (data['occupancy'] as num?)?.toDouble() ?? (capacityWarnings.isNotEmpty ? (capacityWarnings.first['occupancy'] as num).toDouble() : 0.68);
            final isSynthetic = data['is_synthetic'] == true;
            final congestionLevel = (congestion['level'] as String?) ?? 'LOW';
            final congestionFarmers = congestion['farmers_ahead'] ?? 0;
            final congestionThreshold = (thresholds['congestion'] ?? 20);
            final capacityThreshold = (thresholds['capacity'] ?? 0.85);
            final noShowThreshold = (thresholds['no_show'] ?? 0.15);
            Color capColor;
            if (occ > 0.85) {
              capColor = Colors.red;
            } else if (occ > 0.7) {
              capColor = const Color(0xFFEF6C00);
            } else {
              capColor = const Color(0xFF2E7D32);
            }
            Color congColor;
            IconData congIcon;
            if (congestionLevel == 'HIGH') { congColor = Colors.red; congIcon = Icons.error; }
            else if (congestionLevel == 'MEDIUM') { congColor = const Color(0xFFEF6C00); congIcon = Icons.warning; }
            else { congColor = const Color(0xFF2E7D32); congIcon = Icons.check_circle; }
            return Column(children:[
              // 1) Capacity Warnings — LinearProgress + threshold
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                Row(children:[
                  const Icon(Icons.storage, color: Color(0xFF2E7D32), size:18),
                  const SizedBox(width:6),
                  const Text('Capacity Warnings', style: TextStyle(fontWeight: FontWeight.w700, fontSize:13)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:4), decoration: BoxDecoration(color: capColor.withValues(alpha:0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: capColor.withValues(alpha:0.3))), child: Text('${(occ*100).toInt()}% • threshold ${(capacityThreshold*100).toInt()}%', style: TextStyle(fontSize:10, fontWeight: FontWeight.w700, color: capColor))),
                  if (isSynthetic) ...[const SizedBox(width:6), Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: Colors.amber.withValues(alpha:0.2), borderRadius: BorderRadius.circular(8)), child: const Text('Synthetic', style: TextStyle(fontSize:9, color: Color(0xFFBF360C))))],
                ]),
                const SizedBox(height:8),
                Stack(children:[
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: occ.clamp(0.0,1.0), minHeight:10, backgroundColor: Colors.grey.shade200, color: capColor)),
                  Positioned(left: MediaQuery.of(context).size.width * 0.85 * 0.55, child: Container(width:2, height:10, color: Colors.black54)),
                ]),
                const SizedBox(height:4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                  Text('0%', style: TextStyle(fontSize:9, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text('threshold 85%', style: const TextStyle(fontSize:9, fontWeight: FontWeight.w600, color: Colors.black54)),
                  Text('100%', style: TextStyle(fontSize:9, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
                const SizedBox(height:4),
                Text('Occupancy ${(occ*100).toStringAsFixed(1)}% vs threshold ${(capacityThreshold*100).toInt()}% • deterministic', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (capacityWarnings.isNotEmpty) ...[
                  const SizedBox(height:6),
                  ...capacityWarnings.map((w){
                    final m = w as Map;
                    return Padding(padding: const EdgeInsets.symmetric(vertical:2), child: Row(children:[
                      Icon(Icons.warning_amber, size:14, color: capColor),
                      const SizedBox(width:6),
                      Expanded(child: Text(m['message']?.toString() ?? '', style: TextStyle(fontSize:11, color: capColor, fontWeight: FontWeight.w600))),
                    ]));
                  }),
                ] else ...[
                  const SizedBox(height:6),
                  Row(children:[const Icon(Icons.check_circle, size:14, color: Color(0xFF2E7D32)), const SizedBox(width:6), Text('No capacity warning — below threshold', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant))]),
                ],
              ])),
              const SizedBox(height:12),
              // 2) Congestion Alerts — color badge
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                Row(children:[
                  Icon(Icons.traffic, color: congColor, size:18),
                  const SizedBox(width:6),
                  Text(loc.congestionAlerts, style: const TextStyle(fontWeight: FontWeight.w700, fontSize:13)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal:10, vertical:4), decoration: BoxDecoration(color: congColor.withValues(alpha:0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: congColor.withValues(alpha:0.3))), child: Row(mainAxisSize: MainAxisSize.min, children:[
                    Icon(congIcon, size:12, color: congColor),
                    const SizedBox(width:4),
                    Text(congestionLevel, style: TextStyle(fontSize:11, fontWeight: FontWeight.w700, color: congColor)),
                  ])),
                ]),
                const SizedBox(height:8),
                Text(congestion['message']?.toString() ?? 'No congestion', style: TextStyle(fontSize:12, fontWeight: FontWeight.w600, color: congColor)),
                const SizedBox(height:4),
                Text('$congestionFarmers farmers ahead • threshold $congestionThreshold • deterministic', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height:4),
                Text('Thresholds: ${(capacityThreshold*100).toInt()}% capacity, $congestionThreshold farmers, ${(noShowThreshold*100).toInt()}% no-show', style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
              const SizedBox(height:12),
              // 3) Anomaly Detection — list with icon
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                Row(children:[
                  const Icon(Icons.bug_report, color: Color(0xFFBF360C), size:18),
                  const SizedBox(width:6),
                  Text(loc.anomalyDetection, style: const TextStyle(fontWeight: FontWeight.w700, fontSize:13)),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Text('${anomalies.length} anomalies', style: const TextStyle(fontSize:10))),
                ]),
                const SizedBox(height:4),
                Text('Deterministic thresholds 0.85, 20, 15% • synthetic fallback if no data', style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height:8),
                ...anomalies.map((a){
                  final m = a as Map;
                  final type = m['type']?.toString() ?? 'ANOMALY';
                  final sev = m['severity']?.toString() ?? 'info';
                  Color col;
                  IconData icon;
                  if (sev == 'high') { col = Colors.red; }
                  else if (sev == 'medium') { col = const Color(0xFFEF6C00); }
                  else { col = Colors.grey; }
                  if (type == 'CAPACITY_WARNING') { icon = Icons.warning; }
                  else if (type == 'CONGESTION') { icon = Icons.groups; }
                  else if (type == 'NO_SHOW_ANOMALY' || type == 'ANOMALY') { icon = Icons.person_off; }
                  else if (type == 'DUPLICATE_TOKEN') { icon = Icons.copy; }
                  else if (type == 'NORMAL') { icon = Icons.check_circle; col = const Color(0xFF2E7D32); }
                  else { icon = Icons.bug_report; }
                  return Padding(padding: const EdgeInsets.symmetric(vertical:4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[
                    Icon(icon, color: col, size:16),
                    const SizedBox(width:6),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                      Text(m['message']?.toString() ?? '', style: TextStyle(fontSize:12, fontWeight: FontWeight.w600, color: col)),
                      if (m['centre_id'] != null) Text('Centre ${m['centre_id']} • $type', style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ])),
                    Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: col.withValues(alpha:0.12), borderRadius: BorderRadius.circular(8)), child: Text(sev, style: TextStyle(fontSize:9, fontWeight: FontWeight.w700, color: col))),
                  ]));
                }),
              ])),
            ]);
          },
        ),
        const SizedBox(height:12),
        capacityAsync.when(
          loading: ()=> const SizedBox(),
          error: (_,__)=> const SizedBox(),
          data: (cap){
            final occ = (cap['occupancy'] as double? ?? 0.68);
            final warn = (cap['warnings'] as List?) ?? [];
            return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Text(loc.centreCapacity, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height:8),
              LinearProgressIndicator(value: occ, minHeight:8, color: occ>0.85? Colors.red: occ>0.7? const Color(0xFFEF6C00): const Color(0xFF2E7D32)),
              const SizedBox(height:4),
              Text('${(occ*100).toInt()}% today • ${cap['remaining_capacity']} slots remaining • Queue ${cap['current_queue']} • Counters ${cap['active_counters']}', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
              Row(children:[const Icon(Icons.campaign, color: Color(0xFFEF6C00), size:18), const SizedBox(width:6), Text(loc.congestionAlerts, style: const TextStyle(fontWeight: FontWeight.w700, fontSize:13))]),
              const SizedBox(height:8),
              ...alerts.map((a){
                final m=a as Map; final sev=m['severity'] as String? ?? 'info';
                final col = sev=='high'? Colors.red: sev=='medium'? const Color(0xFFEF6C00): Colors.grey;
                return Padding(padding: const EdgeInsets.symmetric(vertical:4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[
                  Icon(sev=='high'? Icons.error: sev=='medium'? Icons.warning: Icons.info, color: col, size:16),
                  const SizedBox(width:6),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                    Text(m['message']?.toString()??'', style: TextStyle(fontSize:12, fontWeight: FontWeight.w600, color: col)),
                    Text(m['action']?.toString()??'', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ])),
                ]));
              }),
              const SizedBox(height:4),
              Text('Not ML — deterministic thresholds queue>15, wait>30, capacity>80%, counters<2', style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
              Text(loc.anomalyDetection, style: const TextStyle(fontWeight: FontWeight.w700, fontSize:13)),
              const SizedBox(height:8),
              ...anomalies.map((a){
                final m=a as Map; final sev=m['severity'] as String? ?? 'info';
                final col = sev=='high'? Colors.red: sev=='medium'? const Color(0xFFEF6C00): Colors.grey;
                return Padding(padding: const EdgeInsets.symmetric(vertical:4), child: Row(children:[
                  Icon(sev=='high'? Icons.bug_report: Icons.check_circle, color: col, size:16),
                  const SizedBox(width:6),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                    Text(m['message']?.toString()??'', style: TextStyle(fontSize:12, color: col)),
                    Text(m['reason']?.toString()??'', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ])),
                ]));
              }),
              const SizedBox(height:4),
              Text('No heavy ML — rule-based queue/spike/capacity/delay', style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
        Text('Reports: Daily centre / Procurement summary / Queue / Payment / Commodity via CSV. No complex BI.', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
    Text(title, style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
  return c.get('/api/v1/analytics/demand-forecast', query: {'centre_id': centreId, 'days': 7});
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
final _p90Provider = FutureProvider.family((ref, (String centreId, int days) params) async {
  final c = ref.watch(apiClientProvider);
  return c.get('/api/v1/analytics/p90', query: {'centre_id': params.$1, 'days': params.$2});
});
final _analyticsAnomaliesProvider = FutureProvider.family((ref, String centreId) async {
  final c = ref.watch(apiClientProvider);
  return c.get('/api/v1/analytics/anomalies', query: {'centre_id': centreId});
});
class _P90Metric extends StatelessWidget {
  final String label; final String value; final String sub; final IconData icon; final bool highlight;
  const _P90Metric({required this.label, required this.value, required this.sub, required this.icon, this.highlight=false});
  @override
  Widget build(BuildContext context){
    return Column(children:[
      Icon(icon, size:16, color: highlight? const Color(0xFFEF6C00): const Color(0xFF2E7D32)),
      const SizedBox(height:4),
      Text(label, style: TextStyle(fontSize:10, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      Text(value, style: TextStyle(fontSize:13, fontWeight: FontWeight.w800, color: highlight? const Color(0xFFEF6C00): Theme.of(context).colorScheme.onSurface)),
      Text(sub, style: TextStyle(fontSize:9, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}
