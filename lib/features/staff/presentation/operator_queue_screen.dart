import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_error.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/providers.dart';
import '../../../core/config/demo_config.dart';
import '../../../models/booking.dart';
import '../../../services/mock/mock_database.dart';
import '../../../services/api/api_queue_repository.dart';
import '../../../core/network/api_client.dart';

class OperatorQueueScreen extends ConsumerStatefulWidget {
  const OperatorQueueScreen({super.key});
  @override
  ConsumerState<OperatorQueueScreen> createState()=> _OperatorQueueScreenState();
}
class _OperatorQueueScreenState extends ConsumerState<OperatorQueueScreen>{
  String _centreId = 'c1';
  @override
  void didChangeDependencies(){
    super.didChangeDependencies();
    final cid = GoRouterState.of(context).uri.queryParameters['centreId'];
    if(cid!=null) _centreId=cid;
  }
  List<QueueStatus> _allowed(String current){
    switch(current.toUpperCase()){
      case 'WAITING': return [QueueStatus.called, QueueStatus.cancelled];
      case 'CALLED': return [QueueStatus.arrived, QueueStatus.noShow, QueueStatus.cancelled];
      case 'ARRIVED': return [QueueStatus.processing, QueueStatus.cancelled];
      case 'PROCESSING': return [QueueStatus.completed, QueueStatus.cancelled];
      case 'ON_HOLD': return [QueueStatus.waiting, QueueStatus.cancelled];
      default: return [QueueStatus.cancelled];
    }
  }
  Future<void> _callNext() async{
    try{
      await ref.read(queueRepositoryProvider).callNext(_centreId);
      ref.read(queueRefreshProvider.notifier).state++;
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Called next farmer')));
      setState((){});
    }catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyMessage(e)))); }
  }
  Future<void> _updateBooking(String id, QueueStatus s) async{
    try{
      await ref.read(queueRepositoryProvider).updateQueueStatus(id, s);
      ref.read(queueRefreshProvider.notifier).state++;
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated to ${s.name}')));
      setState((){});
    }catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyMessage(e)))); }
  }
  Future<void> _recordWeighment(String bookingId) async{
    final ctrl = TextEditingController();
    final grossCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c)=> AlertDialog(
      title: const Text('Record Weighment'),
      content: Column(mainAxisSize: MainAxisSize.min, children:[
        TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal:true), decoration: const InputDecoration(labelText: 'Net weight (quintal)', hintText: '18.5')),
        TextField(controller: grossCtrl, keyboardType: const TextInputType.numberWithOptions(decimal:true), decoration: const InputDecoration(labelText: 'Gross weight (optional)')),
        const SizedBox(height:8),
        Text('Valid 0-500 quintal. Gross ≥ net.', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
      actions:[ TextButton(onPressed: ()=> Navigator.pop(c,false), child: const Text('Cancel')), FilledButton(onPressed: ()=> Navigator.pop(c,true), child: const Text('Save'))],
    ));
    if (ok!=true) return;
    final net = double.tryParse(ctrl.text);
    if (net==null || net<=0 || net>500){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid net weight 0-500'))); return; }
    final gross = double.tryParse(grossCtrl.text);
    try{
      await ref.read(apiClientProvider).post('/api/v1/procurements/$bookingId/weighment', body:{'net_weight': net, if(gross!=null) 'gross_weight': gross});
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Weighment $net q recorded')));
      setState((){});
    }catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
  Future<void> _recordQuality(String bookingId) async{
    String grade='A';
    final moistureCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c)=> StatefulBuilder(builder:(c,setSt)=> AlertDialog(
      title: const Text('Quality Assessment'),
      content: Column(mainAxisSize: MainAxisSize.min, children:[
        DropdownButtonFormField<String>(value: grade, decoration: const InputDecoration(labelText:'Grade'), items: const [DropdownMenuItem(value:'A',child: Text('A')), DropdownMenuItem(value:'B',child: Text('B')), DropdownMenuItem(value:'C',child: Text('C'))], onChanged:(v)=> setSt(()=> grade=v!)),
        TextField(controller: moistureCtrl, keyboardType: const TextInputType.numberWithOptions(decimal:true), decoration: const InputDecoration(labelText: 'Moisture % (0-30)', hintText: '12.5')),
        TextField(controller: remarksCtrl, decoration: const InputDecoration(labelText: 'Remarks (optional)')),
        const SizedBox(height:8),
        Text('Grading per FAQ. Moisture 0–30%.', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
      actions:[ TextButton(onPressed: ()=> Navigator.pop(c,false), child: const Text('Cancel')), FilledButton(onPressed: ()=> Navigator.pop(c,true), child: const Text('Save'))],
    )));
    if (ok!=true) return;
    final moisture = double.tryParse(moistureCtrl.text);
    if (moisture!=null && (moisture<0 || moisture>30)){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moisture 0-30%'))); return; }
    try{
      await ref.read(apiClientProvider).post('/api/v1/procurements/$bookingId/quality', body:{'grade': grade, if(moisture!=null) 'moisture_percent': moisture, if(remarksCtrl.text.isNotEmpty) 'remarks': remarksCtrl.text});
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quality grade $grade recorded')));
      setState((){});
    }catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
  @override
  Widget build(BuildContext context){
    final loc = AppLocalizations.of(context)!;
    if(DemoConfig.useMockBackend){
      final bookings = MockDatabase.instance.bookings.values.toList();
      return Scaffold(
        appBar: AppBar(title: Text('${loc.todayQueue} (Mock)'), actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: 'Scan QR → Arrived', onPressed: () async {
            final ok = await context.push('/operator/scan');
            if (ok == true) setState((){});
          }),
        ]),
        body: bookings.isEmpty? const Center(child: Text('No bookings')) : ListView.separated(padding: const EdgeInsets.all(12), itemCount: bookings.length, separatorBuilder: (_,__)=> const SizedBox(height:8), itemBuilder: (c,i){
          final b = bookings[i];
          return AppCard(child: Row(children:[
            Container(width:48,height:48, decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(b.tokenNumber, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1B5E20))))),
            const SizedBox(width:12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Text('${b.tokenNumber} • ${b.commodity}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${b.centreName} • ${b.queueStatus.name}', style: TextStyle(fontSize:12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('Qty: ${b.quantityQuintal} quintal', style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ])),
              Builder(builder: (cntx){
                final allowed = _allowed(b.queueStatus.name);
                return PopupMenuButton<QueueStatus>(onSelected: (s)=> _updateBooking(b.id,s), itemBuilder: (_)=> allowed.map((e)=> PopupMenuItem(value:e, child: Text(e.name))).toList(), icon: const Icon(Icons.more_vert, color: Color(0xFF5F6368)));
              }),
          ]));
        }),
        floatingActionButton: FloatingActionButton.extended(onPressed: _callNext, icon: const Icon(Icons.campaign), label: const Text('Call Next')),
      );
    }
    final queueRepo = ref.read(queueRepositoryProvider) as ApiQueueRepository;
    return Scaffold(
      appBar: AppBar(title: Text('${loc.todayQueue} • $_centreId'), actions: [
        IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: 'Scan QR → Arrived', onPressed: () async {
          final ok = await context.push('/operator/scan');
          if (ok == true) setState((){});
        }),
      ]),
      body: FutureBuilder<List<Map<String,dynamic>>>(
        future: queueRepo.getCentreQueue(_centreId),
        builder: (context, snap){
          if(snap.connectionState==ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if(snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: ()=>setState((){}));
          final list = snap.data ?? [];
          if(list.isEmpty) return const EmptyState(title:'No bookings', subtitle:'Queue empty', icon: Icons.hourglass_empty);
          return ListView.separated(padding: const EdgeInsets.all(12), itemCount: list.length, separatorBuilder: (_,__)=> const SizedBox(height:8), itemBuilder: (c,i){
            final m = list[i];
            final token = m['token_number'] as String? ?? '';
            final status = m['status'] as String? ?? 'WAITING';
            final farmer = m['farmer_name'] as String? ?? 'Farmer';
            final commodity = m['commodity'] as String? ?? '';
            final qty = m['quantity']?.toString() ?? '';
            final bookingId = m['booking_id'] as String? ?? '';
            return AppCard(child: Row(children:[
              Container(width:48,height:48, decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(token, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1B5E20))))),
              const SizedBox(width:12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                Text('$token • $commodity', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('$farmer • $status', style: TextStyle(fontSize:12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                Text('Qty: $qty quintal • $bookingId'.substring(0, ( 'Qty: $qty quintal • $bookingId').length.clamp(0,40)), style: TextStyle(fontSize:11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ])),
              IconButton(icon: const Icon(Icons.scale, size:18, color: Color(0xFF2E7D32)), tooltip: 'Weighment', onPressed: ()=> _recordWeighment(bookingId)),
              IconButton(icon: const Icon(Icons.verified, size:18, color: Color(0xFF6A1B9A)), tooltip: 'Quality', onPressed: ()=> _recordQuality(bookingId)),
              IconButton(icon: const Icon(Icons.payments, size:18, color: Color(0xFF2E7D32)), tooltip: 'Mark Paid (Complete Payment)', onPressed: () async {
                try{ await ref.read(apiClientProvider).post('/api/v1/payments/$bookingId/status', body:{'status':'COMPLETED'}); ref.read(queueRefreshProvider.notifier).state++; if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment marked COMPLETED'))); setState((){});}catch(e){ if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyMessage(e)))); }
              }),
              Builder(builder: (cntx){
                final allowed = _allowed(status);
                return PopupMenuButton<QueueStatus>(onSelected: (s)=> _updateBooking(bookingId,s), itemBuilder: (_)=> allowed.map((e)=> PopupMenuItem(value:e, child: Text(e.name))).toList(), icon: const Icon(Icons.more_vert, color: Color(0xFF5F6368)));
              }),
            ]));
          });
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _callNext, icon: const Icon(Icons.campaign), label: const Text('Call Next')),
    );
  }
}
