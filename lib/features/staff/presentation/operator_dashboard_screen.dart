import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/config/demo_config.dart';
import '../../../services/mock/mock_database.dart';
import '../../../services/providers.dart';
import '../../../services/api/api_queue_repository.dart';

class OperatorDashboardScreen extends ConsumerWidget {
  const OperatorDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref){
    if(DemoConfig.useMockBackend){
      final db = MockDatabase.instance;
      final total = db.bookings.length + 340;
      final waiting = db.globalCurrentOrdinal < 27 ? 27 - db.globalCurrentOrdinal : 6;
      return Scaffold(
        appBar: AppBar(title: const Text('Operator Dashboard (Mock)'), actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () async { await ref.read(authRepositoryProvider).logout(); if(context.mounted) context.go('/login'); }),
        ]),
        body: _DashboardBody(total: total, waiting: waiting, processing: 41, completed: 217, paymentPending: 21, avgWait: 31, centreName: 'Bhavani Procurement Centre • Operator'),
      );
    }
    final repo = ref.read(queueRepositoryProvider) as ApiQueueRepository;
    return Scaffold(
      appBar: AppBar(title: const Text('Operator Dashboard'), actions: [
        IconButton(icon: const Icon(Icons.logout), onPressed: () async { await ref.read(authRepositoryProvider).logout(); if(context.mounted) context.go('/login'); }),
      ]),
      body: FutureBuilder<Map<String,dynamic>>(
        future: repo.getDashboard('c1'),
        builder: (context, snap){
          if(snap.connectionState==ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if(snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: ()=> ref.invalidate(_dashboardProvider));
          final d = snap.data ?? {};
          return _DashboardBody(
            total: d['today_farmers'] as int? ?? 0,
            waiting: d['waiting'] as int? ?? 0,
            processing: d['processing'] as int? ?? 0,
            completed: d['completed'] as int? ?? 0,
            paymentPending: d['payment_pending'] as int? ?? 0,
            avgWait: d['avg_wait_minutes'] as int? ?? 0,
            centreName: (d['centre_name'] as String? ?? 'Bhavani') + ' • Operator',
          );
        },
      ),
    );
  }
}

final _dashboardProvider = FutureProvider<Map<String,dynamic>>((ref) async {
  final repo = ref.read(queueRepositoryProvider) as ApiQueueRepository;
  return repo.getDashboard('c1');
});

class _DashboardBody extends StatelessWidget {
  final int total, waiting, processing, completed, paymentPending, avgWait;
  final String centreName;
  const _DashboardBody({required this.total, required this.waiting, required this.processing, required this.completed, required this.paymentPending, required this.avgWait, required this.centreName});
  @override
  Widget build(BuildContext context)=> ListView(padding: const EdgeInsets.all(16), children:[
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
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          const Text('Peak Period', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height:4),
          const Text('10 AM – 12 PM • High load expected', style: TextStyle(color: Colors.black54, fontSize:12)),
          const SizedBox(height:8),
          const LinearProgressIndicator(value:0.72, color: Color(0xFFEF6C00)),
        ])),
        const SizedBox(height:12),
        ElevatedButton.icon(icon: const Icon(Icons.groups), label: const Text("VIEW TODAY'S QUEUE"), onPressed: ()=> context.push('/operator/queue')),
        const SizedBox(height:8),
        OutlinedButton.icon(icon: const Icon(Icons.analytics_outlined), label: const Text('ANALYTICS'), onPressed: ()=> context.push('/analytics')),
      ]);
}
class _StatCard extends StatelessWidget{
  final String title; final String value; final String subtitle; final Color color;
  const _StatCard({required this.title, required this.value, required this.subtitle, required this.color});
  @override
  Widget build(BuildContext context)=> AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
    Container(width:36,height:4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
    const SizedBox(height:8),
    Text(title, style: const TextStyle(fontSize:11, color: Colors.black54)),
    Text(value, style: TextStyle(fontSize:22, fontWeight: FontWeight.w800, color: color)),
    Text(subtitle, style: const TextStyle(fontSize:11, color: Colors.black45)),
  ]));
}
