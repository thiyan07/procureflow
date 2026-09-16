import '../../../core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';
import '../../../models/booking.dart';
import '../../../services/mock/mock_database.dart';

class OperatorQueueScreen extends ConsumerStatefulWidget {
  const OperatorQueueScreen({super.key});
  @override
  ConsumerState<OperatorQueueScreen> createState()=> _OperatorQueueScreenState();
}
class _OperatorQueueScreenState extends ConsumerState<OperatorQueueScreen>{
  Future<void> _callNext() async{
    final db = MockDatabase.instance;
    // get first centre
    await ref.read(queueRepositoryProvider).callNext('c1');
    setState((){});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Called next farmer')));
  }
  Future<void> _updateBooking(String id, QueueStatus s) async{
    await ref.read(queueRepositoryProvider).updateQueueStatus(id, s);
    setState((){});
  }
  @override
  Widget build(BuildContext context){
    final bookings = MockDatabase.instance.bookings.values.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Current Queue')),
      body: bookings.isEmpty? const Center(child: Text('No bookings')) : ListView.separated(padding: const EdgeInsets.all(12), itemCount: bookings.length, separatorBuilder: (_,__)=> const SizedBox(height:8), itemBuilder: (c,i){
        final b = bookings[i];
        final ordinal = MockDatabase.instance.bookingOrdinal[b.id] ?? 27;
        return AppCard(child: Row(children:[
          Container(width:48,height:48, decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(b.tokenNumber, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1B5E20))))),
          const SizedBox(width:12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Text(b.tokenNumber + ' • ' + b.commodity, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(b.centreName + ' • ' + b.queueStatus.name, style: const TextStyle(fontSize:12, color: Colors.black54)),
            Text('Qty: ${b.quantityQuintal} quintal', style: const TextStyle(fontSize:11, color: Colors.black45)),
          ])),
          PopupMenuButton<QueueStatus>(onSelected: (s)=> _updateBooking(b.id,s), itemBuilder: (_)=> QueueStatus.values.map((e)=> PopupMenuItem(value:e, child: Text(e.name))).toList(), child: const Icon(Icons.more_vert)),
        ]));
      }),
      floatingActionButton: FloatingActionButton.extended(onPressed: _callNext, icon: const Icon(Icons.campaign), label: const Text('Call Next')),
    );
  }
}
