import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/network/api_error.dart';
import '../../../services/providers.dart';
import '../../../models/slot.dart';
import '../../../models/analytics.dart';
import '../../../models/booking.dart';
import '../../../l10n/app_localizations.dart';

class SlotBookingScreen extends ConsumerStatefulWidget {
  const SlotBookingScreen({super.key});
  @override
  ConsumerState<SlotBookingScreen> createState() => _SlotBookingScreenState();
}

class _CommodityRowData {
  String commodity;
  final qtyCtrl = TextEditingController();
  _CommodityRowData(this.commodity, String qty){ qtyCtrl.text = qty; }
  void dispose()=> qtyCtrl.dispose();
}

class _SlotBookingScreenState extends ConsumerState<SlotBookingScreen> {
  final List<_CommodityRowData> _rows = [_CommodityRowData('Paddy','18.5')];
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
  void dispose(){ for(final r in _rows) r.dispose(); super.dispose(); }

  Future<void> _confirm() async {
    if (_selectedSlotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a slot')));
      return;
    }
    // Validate multi-commodity rows
    final List<Map<String,dynamic>> commodities = [];
    for(final row in _rows){
      final q = double.tryParse(row.qtyCtrl.text);
      if (q==null || q<=0){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter valid quantity for ${row.commodity}')));
        return;
      }
      if (q>500){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quantity too high for ${row.commodity} (max 500)')));
        return;
      }
      commodities.add({'commodity': row.commodity, 'quantity': q});
    }
    if (commodities.length > 5){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 5 commodities per booking')));
      return;
    }
    // For single, use legacy; for multi, send list
    final primary = commodities.first;
    final totalQty = commodities.fold(0.0, (a,e)=> a + (e['quantity'] as double));
    setState(()=> _booking=true);
    try{
      final auth = await ref.read(authRepositoryProvider).getCurrentUser();
      if (auth==null) throw Exception('Not logged in');
      final repo = ref.read(slotRepositoryProvider);
      // Build CommodityItem list for API
      List<CommodityItem>? commItems;
      if (commodities.length > 1){
        commItems = commodities.map((e)=> CommodityItem(commodity: e['commodity'] as String, quantity: e['quantity'] as double)).toList();
      }
      final booking = await repo.bookSlot(farmerId: auth.id, centreId: _centreId, commodity: primary['commodity'] as String, quantity: primary['quantity'] as double, slotId: _selectedSlotId!, commodities: commItems);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking successful! Token ${booking.tokenNumber}')));
      context.go('/token');
    } catch(e){
      final friendly = userFriendlyMessage(e);
      // Special handling for duplicate booking: navigate to token
      if (e.toString().contains('DUPLICATE_BOOKING')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendly),
          action: SnackBarAction(label: 'View Token', onPressed: () => context.go('/token')),
          duration: const Duration(seconds: 4),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendly)));
      }
    } finally{ if(mounted) setState(()=> _booking=false); }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final slotsAsync = ref.watch(_slotsProvider((_centreId, _date)));
    final centresAsync = ref.watch(_centresForDropdown);
    final commoditiesAsync = ref.watch(_commoditiesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(loc.bookSlot)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Multi-commodity
        Row(children:[
          Text(loc.selectCommodity, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width:8),
          Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)), child: Text(loc.multiCommoditySupported, style: const TextStyle(fontSize:10, color: Color(0xFF2E7D32)))),
        ]),
        const SizedBox(height:4),
        const Text('Example: Paddy 350 kg + Maize 150 kg in one token (max 5). Reuses same slot capacity.', style: TextStyle(fontSize:11, color: Colors.black54)),
        const SizedBox(height:8),
        ..._rows.asMap().entries.map((entry){
          final idx = entry.key;
          final row = entry.value;
          final commodities = commoditiesAsync.maybeWhen(data: (list)=> list, orElse: ()=> AppConstants.commodities);
          return Padding(padding: const EdgeInsets.only(bottom:8), child: Row(children:[
            Expanded(flex: 3, child: DropdownButtonFormField<String>(value: commodities.contains(row.commodity) ? row.commodity : commodities.first, decoration: InputDecoration(labelText: 'Commodity ${idx+1}'), items: commodities.map((c)=> DropdownMenuItem(value:c, child: Text(c, style: const TextStyle(fontSize:12)))).toList(), onChanged: (v)=> setState(()=> row.commodity=v!))),
            const SizedBox(width:8),
            Expanded(flex: 2, child: TextFormField(controller: row.qtyCtrl, keyboardType: const TextInputType.numberWithOptions(decimal:true), decoration: const InputDecoration(labelText: 'Qty (q)', hintText: '18.5'))),
            if (_rows.length > 1) IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: ()=> setState(()=> _rows.removeAt(idx))),
          ]));
        }),
        Align(alignment: Alignment.centerLeft, child: _rows.length < 3 ? TextButton.icon(icon: const Icon(Icons.add), label: Text(loc.addCommodity), onPressed: ()=> setState(()=> _rows.add(_CommodityRowData('Maize','10')))) : const SizedBox()),
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
final _commoditiesProvider = FutureProvider<List<String>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final list = await client.getList('/api/v1/commodities');
    final names = list.map((e) => (e as Map)['name'] as String).toList();
    if (names.isNotEmpty) return names;
  } catch (_) {}
  return AppConstants.commodities;
});
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
