import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';
import '../../../models/slot.dart';
import '../../../models/analytics.dart';

class SlotBookingScreen extends ConsumerStatefulWidget {
  const SlotBookingScreen({super.key});
  @override
  ConsumerState<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _SlotBookingScreenState extends ConsumerState<SlotBookingScreen> {
  String _commodity = 'Paddy';
  final _qtyCtrl = TextEditingController(text: '18.5');
  String _centreId = 'c1';
  String _centreName = 'Bhavani Procurement Centre';
  DateTime _date = DateTime.now();
  String? _selectedSlotId;
  bool _booking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    final cid = uri.queryParameters['centreId'];
    final cname = uri.queryParameters['centreName'];
    if (cid != null) {
      _centreId = cid;
      if (cname != null) _centreName = Uri.decodeComponent(cname);
    }
  }

  @override
  void dispose(){ _qtyCtrl.dispose(); super.dispose(); }

  Future<void> _confirm() async {
    if (_selectedSlotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a slot')));
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <=0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid quantity')));
      return;
    }
    setState(()=> _booking=true);
    try{
      final auth = await ref.read(authRepositoryProvider).getCurrentUser();
      if (auth==null) throw Exception('Not logged in');
      final repo = ref.read(slotRepositoryProvider);
      final booking = await repo.bookSlot(farmerId: auth.id, centreId: _centreId, commodity: _commodity, quantity: qty, slotId: _selectedSlotId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking successful! Token ${booking.tokenNumber}')));
      context.go('/token');
    } catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally{ if(mounted) setState(()=> _booking=false); }
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(_slotsProvider((_centreId, _date)));
    final centresAsync = ref.watch(_centresForDropdown);
    return Scaffold(
      appBar: AppBar(title: const Text('Book Slot')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Commodity
        Text('Select commodity', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:8),
        DropdownButtonFormField<String>(value: _commodity, decoration: const InputDecoration(labelText: 'Commodity'), items: AppConstants.commodities.map((c)=> DropdownMenuItem(value:c, child: Text(c))).toList(), onChanged: (v)=> setState(()=> _commodity=v!)),
        const SizedBox(height:12),
        TextFormField(controller: _qtyCtrl, keyboardType: const TextInputType.numberWithOptions(decimal:true), decoration: const InputDecoration(labelText: 'Estimated quantity (quintal)', hintText: '18.5')),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(
          value: _centreId,
          decoration: const InputDecoration(labelText: 'Procurement Centre'),
          items: centresAsync.when(
            data: (list)=> list.map((c)=> DropdownMenuItem(value:c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
            loading: ()=> [],
            error: (_,__)=> [],
          ),
          onChanged: (v){ if(v!=null) setState((){ _centreId=v; _selectedSlotId=null; }); },
        ),
        const SizedBox(height:12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days:7)));
            if(picked!=null) setState((){ _date=picked; _selectedSlotId=null; });
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_today)),
            child: Text(DateFormat('dd MMM, yyyy').format(_date)),
          ),
        ),
        const SizedBox(height:16),
        Text('Available slots • ${DateFormat('dd MMM').format(_date)}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:8),
        slotsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e,s) => ErrorState(message: e.toString(), onRetry:()=> ref.invalidate(_slotsProvider((_centreId,_date)))),
          data: (slots){
            if (slots.isEmpty) return const Text('No slots');
            return Column(children: slots.map((s)=> _SlotTile(
              slot: s,
              selected: s.id==_selectedSlotId,
              onTap: s.isFull ? null : ()=> setState(()=> _selectedSlotId=s.id),
            )).toList());
          },
        ),
        const SizedBox(height:12),
        // AI recommendation preview
        Consumer(builder: (context, ref, _){
          final slots = slotsAsync.value;
          if (slots==null) return const SizedBox();
          final rec = slots.where((s)=> s.isRecommended).firstOrNull;
          if (rec==null) return const SizedBox();
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.primaryGreen.withValues(alpha:0.3))),
            child: Row(children:[
              const Icon(Icons.lightbulb, color: AppTheme.primaryGreen),
              const SizedBox(width:8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                const Text('Recommended - Lower expected load', style: TextStyle(fontWeight: FontWeight.w700, fontSize:12, color: AppTheme.primaryGreen)),
                Text('${DateFormat('hh:mm a').format(rec.start)} • ${rec.available} slots • Est. wait ~${(rec.booked*3/3).ceil()} min', style: const TextStyle(fontSize:12)),
              ])),
            ]),
          );
        }),
        const SizedBox(height:20),
        PrimaryButton(label: 'Confirm Booking', onPressed: _booking? null: _confirm, loading: _booking, icon: Icons.check_circle),
        const SizedBox(height:8),
        Text('Centre: $_centreName', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize:12)),
      ]),
    );
  }
}

final _centresForDropdown = FutureProvider((ref) async => ref.watch(centreRepositoryProvider).getCentres());
final _slotsProvider = FutureProvider.family<List<Slot>, (String, DateTime)>((ref, arg) async {
  final (cid, date) = arg;
  return ref.watch(slotRepositoryProvider).getSlots(cid, date);
});

class _SlotTile extends StatelessWidget {
  final Slot slot;
  final bool selected;
  final VoidCallback? onTap;
  const _SlotTile({required this.slot, required this.selected, this.onTap});
  @override
  Widget build(BuildContext context){
    final time = DateFormat('hh:mm a').format(slot.start);
    final avail = slot.available;
    final isFull = slot.isFull;
    return Card(
      color: selected ? const Color(0xFFE8F5E9) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: selected ? AppTheme.primaryGreen : const Color(0xFFE0E5DE))),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width:44,height:44,
          decoration: BoxDecoration(color: isFull ? Colors.grey.shade200 : AppTheme.primaryGreen.withValues(alpha:0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.schedule, color: isFull? Colors.grey: AppTheme.primaryGreen),
        ),
        title: Row(children:[
          Text(time, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (slot.isRecommended) ...[const SizedBox(width:6), Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(10)), child: const Text('Recommended', style: TextStyle(color: Colors.white, fontSize:10)))],
        ]),
        subtitle: Text(isFull? 'FULL • ${slot.booked}/${slot.capacity}' : '$avail slots • ${slot.booked}/${slot.capacity} booked'),
        trailing: isFull? const Text('FULL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)) : Radio(value: true, groupValue: selected, onChanged: (_)=> onTap?.call()),
      ),
    );
  }
}

extension<T> on List<T> { T? get firstOrNull => isEmpty? null: first; }
