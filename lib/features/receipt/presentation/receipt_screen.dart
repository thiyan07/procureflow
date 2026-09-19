import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';

class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref){
    final bookingId = GoRouterState.of(context).uri.queryParameters['bookingId'];
    if (bookingId==null) return Scaffold(appBar: AppBar(title: const Text('Receipt')), body: const Center(child: Text('No bookingId')));
    return Scaffold(
      appBar: AppBar(title: const Text('Digital Receipt')),
      body: FutureBuilder<Map<String,dynamic>>(
        future: ref.read(apiClientProvider).get('/api/v1/procurements/$bookingId/receipt'),
        builder: (c,snap){
          if (snap.connectionState==ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorState(message: snap.error.toString());
          final data = snap.data!;
          final farmer = data['farmer'] as Map? ?? {};
          final centre = data['centre'] as Map? ?? {};
          final payment = data['payment'] as Map? ?? {};
          final weighment = data['weighment'] as Map? ?? {};
          final quality = data['quality'] as Map? ?? {};
          return ListView(padding: const EdgeInsets.all(16), children:[
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE0E5DE)), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Row(children:[const Icon(Icons.receipt_long, color: Color(0xFF2E7D32)), const SizedBox(width:8), const Text('ProcureFlow Receipt', style: TextStyle(fontWeight: FontWeight.w800, fontSize:16))]),
              const Divider(height:20),
              _Row(label:'Reference', value: data['reference'] as String? ?? ''),
              _Row(label:'Farmer', value: '${farmer['name']??''} (${farmer['farmer_id']??''})'),
              _Row(label:'Village', value: farmer['village']??''),
              _Row(label:'Centre', value: '${centre['name']??''}'),
              _Row(label:'Date', value: data['date']??''),
              _Row(label:'Slot', value: data['slot']??''),
              const SizedBox(height:8),
              const Text('Commodities', style: TextStyle(fontWeight: FontWeight.w700, fontSize:12)),
              ...(data['commodities'] as List? ?? []).map((e){
                final m=e as Map; return Padding(padding: const EdgeInsets.symmetric(vertical:2), child: Text('• ${m['commodity']}: ${m['quantity']} ${m['unit']??'quintal'}', style: const TextStyle(fontSize:12)));
              }),
              const SizedBox(height:8),
              const Text('Weighment', style: TextStyle(fontWeight: FontWeight.w700, fontSize:12)),
              Text('Gross: ${weighment['gross']??'-'} / Net: ${weighment['net']??'-'} ${weighment['time']!=null? 'at ${weighment['time']}':''}', style: const TextStyle(fontSize:12)),
              const SizedBox(height:4),
              const Text('Quality', style: TextStyle(fontWeight: FontWeight.w700, fontSize:12)),
              Text('Grade: ${quality['grade']??'-'} / Moisture: ${quality['moisture']??'-'}% / ${quality['remarks']??''}', style: const TextStyle(fontSize:12)),
              const Divider(height:20),
              _Row(label:'Procurement', value: (data['procurement'] as Map?)?['stage']?.toString() ?? ''),
              _Row(label:'Payment', value: '${payment['status']??''} ₹${payment['amount']??''}'),
              _Row(label:'Transaction', value: payment['transaction_id']?? 'Pending'),
              _Row(label:'Payment Date', value: payment['date']??'-'),
              const SizedBox(height:12),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)), child: const Text('This is a digital receipt for demo. No real payment gateway. Keep for records.', style: TextStyle(fontSize:11, color: Color(0xFF1B5E20)))),
            ])),
            const SizedBox(height:12),
            const Text('Lightweight receipt — no PDF dependency, printable via screenshot.', textAlign: TextAlign.center, style: TextStyle(fontSize:11, color: Colors.black45)),
            const SizedBox(height:12),
            FilledButton.icon(icon: const Icon(Icons.share), label: const Text('Share Reference'), onPressed: ()=> ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reference ${data['reference']} copied')))),
          ]);
        },
      ),
    );
  }
}
class _Row extends StatelessWidget{
  final String label; final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext c)=> Padding(padding: const EdgeInsets.symmetric(vertical:2), child: Row(children:[SizedBox(width:90, child: Text(label, style: const TextStyle(color: Colors.black54, fontSize:11))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize:12)))]));
}
