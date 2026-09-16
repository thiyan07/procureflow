import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref){
    final loadAsync = ref.watch(_loadProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(padding: const EdgeInsets.all(16), children:[
        Row(children:[
          Expanded(child: _Kpi(title:'Farmers/day', value:'342', icon: Icons.groups)),
          const SizedBox(width:12),
          Expanded(child: _Kpi(title:'Avg wait', value:'31 min', icon: Icons.schedule)),
        ]),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child: _Kpi(title:'Completed', value:'217', icon: Icons.check_circle)),
          const SizedBox(width:12),
          Expanded(child: _Kpi(title:'No-show', value:'4.2%', icon: Icons.person_off)),
        ]),
        const SizedBox(height:16),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          const Text('Centre Load Prediction (Tomorrow)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height:12),
          SizedBox(height:160, child: loadAsync.when(
            loading: ()=> const Center(child: CircularProgressIndicator()),
            error: (e,s)=> Text('Error $e'),
            data: (list)=> BarChart(BarChartData(
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
            )),
          )),
          const SizedBox(height:6),
          const Text('Peak 10 AM - 12 PM', style: TextStyle(fontSize:11, color: Colors.black54)),
        ])),
        const SizedBox(height:12),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          const Text('Centre Utilization', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height:8),
          const LinearProgressIndicator(value:0.68, minHeight:8),
          const SizedBox(height:4),
          const Text('68% today • 22 slots remaining', style: TextStyle(fontSize:11, color: Colors.black54)),
        ])),
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
final _loadProvider = FutureProvider((ref)=> ref.watch(aiRepositoryProvider).predictCentreLoad('c1', DateTime.now().add(const Duration(days:1))));
