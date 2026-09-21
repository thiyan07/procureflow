import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';
import '../../../models/centre.dart';

class CentresScreen extends ConsumerWidget {
  const CentresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centresAsync = ref.watch(_centresProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Procurement Centres')),
      body: centresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,s) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(_centresProvider)),
        data: (centres) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_centresProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: centres.length,
            separatorBuilder: (_,__) => const SizedBox(height:12),
            itemBuilder: (context, i) {
              final c = centres[i];
              return _CentreCard(centre: c);
            },
          ),
        ),
      ),
    );
  }
}

final _centresProvider = FutureProvider<List<ProcurementCentre>>((ref) async {
  final repo = ref.watch(centreRepositoryProvider);
  return repo.getCentres();
});

class _CentreCard extends StatelessWidget {
  final ProcurementCentre centre;
  const _CentreCard({required this.centre});
  @override
  Widget build(BuildContext context) {
    final isOpen = centre.isOpen;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha:0.12), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.store, color: AppTheme.primaryGreen)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(centre.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Theme.of(context).textTheme.titleMedium?.color), maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(centre.location, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha:0.7) ?? Colors.black54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
          StatusChip(label: centre.status.toUpperCase(), color: isOpen ? AppTheme.success : AppTheme.warning, icon: isOpen ? Icons.check_circle : Icons.pause_circle),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _StatChip(icon: Icons.groups, label: 'Queue ${centre.currentQueue}'),
          const SizedBox(width: 8),
          _StatChip(icon: Icons.schedule, label: '${centre.estimatedWaitMinutes} min'),
          const SizedBox(width: 8),
          _StatChip(icon: Icons.event_available, label: '${centre.availableSlots} slots'),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing:6, children: centre.commodities.map((e) => Chip(label: Text(e, style: const TextStyle(fontSize:11)), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList()),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.calendar_today, size:18), label: const Text('VIEW SLOTS'), onPressed: () => context.push('/slots?centreId=${centre.id}&centreName=${Uri.encodeComponent(centre.name)}'))),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E352E) : const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF3E4A3E) : const Color(0xFFD0E8D0)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: isDark ? const Color(0xFF81C784) : AppTheme.primaryGreen),
        const SizedBox(width:4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimary)),
      ]),
    );
  }
}
