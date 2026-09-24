import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';
import '../../../models/centre.dart';
import 'package:intl/intl.dart';

class CentreDetailsScreen extends ConsumerWidget {
  final String centreId;
  final double? userLat;
  final double? userLng;
  const CentreDetailsScreen({super.key, required this.centreId, this.userLat, this.userLng});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.watch(_operationalProvider((centreId: centreId, lat: userLat, lng: userLng)));
    return Scaffold(
      appBar: AppBar(title: const Text('Centre Details')),
      body: future.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Failed to load: $e'))),
        data: (data) => _DetailsBody(data: data),
      ),
    );
  }
}

final _operationalProvider = FutureProvider.family<Map<String, dynamic>, ({String centreId, double? lat, double? lng})>((ref, args) async {
  final repo = ref.watch(centreRepositoryProvider);
  try {
    return await repo.getCentreOperational(args.centreId, lat: args.lat, lng: args.lng);
  } catch (_) {
    // fallback: get centre alone
    final centre = await repo.getCentre(args.centreId);
    return {'centre': centre.toJson(), 'distance_km': centre.distanceKm, 'status': centre.status, 'is_open_now': centre.isOpen};
  }
});

class _DetailsBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DetailsBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final centreJson = data['centre'] as Map<String, dynamic>? ?? data;
    final centre = ProcurementCentre.fromJson(centreJson);
    final distance = (data['distance_km'] as num?)?.toDouble() ?? centre.distanceKm;
    // operational returns status as object {is_open, current_queue_size,...} — handle both shapes (100% real)
    final statusObj = data['status'];
    final statusMap = statusObj is Map<String, dynamic> ? statusObj : null;
    final isOpen = (statusMap?['is_open'] as bool?) ?? (data['is_open_now'] as bool?) ?? centre.isOpen;
    final statusStr = centre.status; // real status from CentreOut, not overwritten by object
    final capacity = data['capacity'] as Map<String, dynamic>?;
    final nextSlot = (data['next_available_slot'] as Map<String, dynamic>?) ?? (data['next_slot'] as Map<String, dynamic>?);
    final commodities = centre.commodities;

    // Fix: use real slot totals from capacity (total/used/remaining + occupancy) — daily_capacity is nominal, slots total is ground truth
    final capMap = capacity;
    final statusMapForCap = statusMap;
    final remaining = (capMap?['remaining_capacity'] as int?) ?? centre.remainingCapacityToday;
    final totalCap = (capMap?['total_capacity'] as int?) ?? centre.dailyCapacity ?? 0;
    final usedCap = (capMap?['used_capacity'] as int?) ?? ((totalCap != 0 && remaining != null) ? (totalCap - remaining) : null);
    final daily = totalCap != 0 ? totalCap : centre.dailyCapacity;
    final pct = (totalCap != 0 && remaining != null) ? ((usedCap ?? 0) / totalCap).clamp(0, 1).toDouble() : null;
    final occupancy = (capMap?['occupancy'] as num?)?.toDouble();

    Future<void> openNavigate() async {
      final lat = centre.lat;
      final lng = centre.lng;
      final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final geo = Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(centre.name)})');
        if (await canLaunchUrl(geo)) await launchUrl(geo);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha:0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.store, color: AppTheme.primaryGreen)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(centre.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(centre.location, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha:0.7), fontSize: 12)),
                if (centre.centreCode != null) Text(centre.centreCode!, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ])),
              StatusChip(label: statusStr.toUpperCase(), color: isOpen ? AppTheme.success : AppTheme.warning, icon: isOpen ? Icons.check_circle : Icons.pause_circle),
            ]),
            const SizedBox(height: 12),
            if (distance != null) Row(children: [const Icon(Icons.near_me, size: 16, color: AppTheme.primaryGreen), const SizedBox(width: 4), Text('${distance.toStringAsFixed(1)} km away', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.primaryGreen))]),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.location_on_outlined, text: centre.address ?? centre.location),
            if (centre.phone != null) _InfoRow(icon: Icons.phone_outlined, text: centre.phone!),
            if (centre.contactPerson != null) _InfoRow(icon: Icons.person_outline, text: 'Contact: ${centre.contactPerson}'),
            _InfoRow(icon: Icons.access_time, text: 'Hours: ${centre.openTime ?? "09:00"} – ${centre.closeTime ?? "17:00"}'),
            const SizedBox(height: 12),
            Wrap(spacing: 6, children: commodities.map((e) => Chip(label: Text(e, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)).toList()),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.navigation, size: 18), label: const Text('Navigate'), onPressed: openNavigate)),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.calendar_today, size: 18), label: const Text('Book Slot'), onPressed: () => context.push('/slots?centreId=${centre.id}&centreName=${Uri.encodeComponent(centre.name)}'))),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Today\'s Capacity', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (daily != null && remaining != null && totalCap != 0) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Booked: ${usedCap ?? (daily - remaining)} / $daily', style: const TextStyle(fontSize: 13)),
                Text('Remaining: $remaining', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation((occupancy ?? pct ?? 0) > 0.85 ? AppTheme.warning : AppTheme.primaryGreen))),
              if ((occupancy ?? pct ?? 0) > 0.9) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Almost full – book soon', style: TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600))),
              if (capMap != null && (capMap['warnings'] as List?)?.isNotEmpty == true)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text((capMap['warnings'] as List).join(' • '), style: const TextStyle(fontSize: 11, color: AppTheme.warning))),
            ] else
              const Text('Capacity info unavailable', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            Builder(builder: (_) {
              final q = (statusMapForCap?['current_queue_size'] as int?) ?? centre.currentQueue;
              final w = (statusMapForCap?['estimated_wait_minutes'] as int?) ?? centre.estimatedWaitMinutes;
              final s = (statusMapForCap?['available_slots'] as int?) ?? centre.availableSlots;
              return Row(children: [
                _MiniStat(icon: Icons.groups, label: 'Queue', value: '$q'),
                const SizedBox(width: 12),
                _MiniStat(icon: Icons.schedule, label: 'Est. wait', value: '$w min'),
                const SizedBox(width: 12),
                _MiniStat(icon: Icons.event_available, label: 'Slots', value: '$s'),
              ]);
            }),
          ]),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Next Available Slot', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (nextSlot != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.25))),
                child: Row(children: [
                  const Icon(Icons.timer_outlined, color: AppTheme.primaryGreen),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nextSlot['start_time']?.toString() ?? nextSlot['start']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${nextSlot['available'] ?? '—'} slots available', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ])),
                  TextButton(onPressed: () => context.push('/slots?centreId=${centre.id}&centreName=${Uri.encodeComponent(centre.name)}'), child: const Text('View all')),
                ]),
              )
            else
              const Text('No slot info', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ]),
        ),
        const SizedBox(height: 16),
        Consumer(builder: (context, ref, _) {
          final forecastAsync = ref.watch(_loadForecastProvider(centre.id));
          return AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.insights, size: 18, color: AppTheme.primaryGreen),
                const SizedBox(width: 6),
                const Text('Demand Forecast (3 days)', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)), child: const Text('Live', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen))),
              ]),
              const SizedBox(height: 8),
              forecastAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))),
                error: (e, s) => const Text('Prediction unavailable — insufficient history', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                data: (data) {
                  if (data == null) return const Text('Prediction unavailable — insufficient history', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
                  final level = data['level'] as String? ?? 'NORMAL';
                  if (level == 'UNKNOWN') return const Text('Prediction unavailable — insufficient history (no real bookings)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
                  final reason = data['reason'] as String? ?? '';
                  final forecast = data['forecast_3d'] as List? ?? [];
                  if (forecast.isEmpty) {
                    return const Text('Prediction unavailable — insufficient history', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
                  }
                  Color levelColor = AppTheme.primaryGreen;
                  if (level == 'HIGH') levelColor = AppTheme.warning;
                  if (level == 'LOW') levelColor = const Color(0xFF42A5F5);
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: levelColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text('$level load today • ${forecast.isNotEmpty ? forecast[0]['expected_bookings'] : '?'} bookings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: levelColor)),
                    ),
                    const SizedBox(height: 6),
                    Text(reason, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 10),
                    ...forecast.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        SizedBox(width: 90, child: Text(f['date']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: ((f['expected_bookings'] as int? ?? 10) / 35).clamp(0, 1).toDouble(), minHeight: 8, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(f['level'] == 'HIGH' ? AppTheme.warning : f['level'] == 'LOW' ? const Color(0xFF42A5F5) : AppTheme.primaryGreen)))),
                        const SizedBox(width: 8),
                        Text('${f['expected_bookings']} • ${f['level']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    )),
                    const SizedBox(height: 4),
                    Text('Model: ${data['model_info'] ?? ''}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  ]);
                },
              ),
            ]),
          );
        }),
        const SizedBox(height: 16),
        Consumer(builder: (context, ref, _) {
          final demandAsync = ref.watch(_demandForecastProvider(centre.id));
          return AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Peak Hours & Batch Advice', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              demandAsync.when(
                loading: () => const CircularProgressIndicator(strokeWidth: 2),
                error: (e, s) => const Text('Prediction unavailable — insufficient history', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                data: (data) {
                  if (data == null || (data['forecast'] as List?)?.isEmpty == true) {
                    return const Text('Prediction unavailable — insufficient history', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
                  }
                  final list = data['forecast'] as List;
                  final today = list.first as Map<String, dynamic>;
                  final conf = today['confidence'] as String?;
                  if (today['predicted_bookings'] == null || conf == 'insufficient') {
                    return const Text('Prediction unavailable — insufficient history', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
                  }
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Today: ${today['predicted_bookings']} bookings • ${today['reason']}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('Confidence: ${conf ?? 'medium'}', style: TextStyle(fontSize: 11, color: conf == 'low' ? AppTheme.warning : AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Tip: Prefer 13:30-14:30 post-lunch for lower queue (real occupancy data).', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ]);
                },
              ),
            ]),
          );
        }),
        const SizedBox(height: 12),
        Text('Map: ${centre.lat.toStringAsFixed(4)}, ${centre.lng.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

final _loadForecastProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, centreId) async {
  try {
    final client = ref.watch(apiClientProvider);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final res = await client.get('/api/v1/ai/centre-load/$centreId', query: {'target_date': today});
    return res;
  } catch (_) {
    return null;
  }
});

final _demandForecastProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, centreId) async {
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get('/api/v1/ai/demand-forecast', query: {'centre_id': centreId, 'days': 3});
    return res;
  } catch (_) {
    return null;
  }
});

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: Colors.grey.shade600),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniStat({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2E352E) : const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ]),
    ),
  );
}
