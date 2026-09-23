import '../../../core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/network/api_error.dart';
import '../../../services/providers.dart';
import '../../../services/repositories.dart';
import '../../../models/booking.dart';
import '../../../core/utils/date_utils.dart';
import '../../../l10n/app_localizations.dart';

class ProcurementScreen extends ConsumerWidget {
  const ProcurementScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final bookingAsync = ref.watch(_activeBookingProvider);
    return Scaffold(
      appBar: AppBar(title: Text(loc.procurement)),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,s) => ErrorState(message: e.toString()),
        data: (booking) {
          if (booking==null) return const EmptyState(title: 'No procurement', subtitle: 'Book a slot and complete queue.', icon: Icons.timeline_outlined);
          return FutureBuilder(
            future: ref.read(procurementRepositoryProvider).getProcurementTimeline(booking.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: ()=> ref.invalidate(_activeBookingProvider));
              if (!snap.hasData || snap.data == null) return const ErrorState(message: 'Procurement timeline unavailable');
              final steps = snap.data!;
              return ListView(padding: const EdgeInsets.all(16), children: [
                AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(booking.centreName, style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                  Text('${booking.commodity} • ${booking.quantityQuintal} quintal • ${booking.tokenNumber}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize:12)),
                ])),
                const SizedBox(height:12),
                AppCard(child: Column(children: steps.map((s) => _TimelineTile(step: s)).toList())),
                const SizedBox(height:12),
                // Approval status chip — visible to all
                FutureBuilder<Map<String, dynamic>>(
                  future: ref.read(procurementRepositoryProvider).getProcurement(booking.id).catchError((_) => <String,dynamic>{'approval_status':'NONE'}),
                  builder: (context, procSnap) {
                    final data = procSnap.data;
                    final status = (data?['approval_status'] as String?) ?? 'NONE';
                    final pending = data?['pending_stage'] as String?;
                    Color chipColor;
                    String chipLabel;
                    switch (status) {
                      case 'PENDING':
                        chipColor = const Color(0xFFEF6C00);
                        chipLabel = pending != null ? 'PENDING • $pending' : 'PENDING ADMIN';
                        break;
                      case 'OPERATOR_APPROVED':
                        chipColor = const Color(0xFF1565C0);
                        chipLabel = 'OPERATOR_APPROVED';
                        break;
                      case 'ADMIN_APPROVED':
                        chipColor = const Color(0xFF2E7D32);
                        chipLabel = 'ADMIN_APPROVED';
                        break;
                      default:
                        chipColor = Colors.grey;
                        chipLabel = status == 'NONE' ? 'No approval needed' : status;
                    }
                    return AppCard(child: Row(children: [
                      const Icon(Icons.verified_user, size: 16, color: Color(0xFF6A1B9A)),
                      const SizedBox(width: 8),
                      const Text('Approval:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: chipColor.withValues(alpha: 0.3))),
                        child: Text(chipLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: chipColor))),
                      if (pending != null) ...[const SizedBox(width: 8), Expanded(child: Text('→ $pending', style: const TextStyle(fontSize: 11, color: Color(0xFF6A1B9A)), overflow: TextOverflow.ellipsis))],
                    ]));
                  },
                ),
                const SizedBox(height:12),
                // Role-based actions: operator proposes, admin approves
                Consumer(builder: (context, ref, _) {
                  final auth = ref.watch(authStateProvider).valueOrNull;
                  final role = auth?.role;
                  final isOperator = role == 'CENTRE_OPERATOR';
                  final isAdmin = role == 'ADMIN';
                  if (!isOperator && !isAdmin) {
                    return AppCard(child: Row(children: [const Icon(Icons.info_outline, size: 18, color: Color(0xFF6A1B9A)), const SizedBox(width: 8), Expanded(child: Text('Tracking is live — updates from centre operator.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))) ]));
                  }
                  // Payment action: always visible for operator/admin when payment PENDING/PROCESSING (even before COMPLETED)
                  return FutureBuilder<dynamic>(
                    future: (() async { try { return await ref.read(paymentRepositoryProvider).getPayment(booking.id); } catch(_){ return null; } })(),
                    builder: (context, paySnap){
                      final pay = paySnap.data;
                      final status = pay?.status.name.toUpperCase() ?? 'PENDING';
                      if (booking.procurementStage == ProcurementStage.paymentCompleted) return const SizedBox();
                      if (booking.procurementStage == ProcurementStage.completed) {
                        if (pay?.status == PaymentStatus.completed) {
                          return AppCard(child: Row(children:[const Icon(Icons.check_circle, color: Color(0xFF2E7D32)), const SizedBox(width:8), Text('Payment $status — credited', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700))]));
                        }
                        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children:[
                          AppCard(child: Row(children:[const Icon(Icons.payments, color: Color(0xFFEF6C00)), const SizedBox(width:8), Text('Payment $status', style: const TextStyle(fontWeight: FontWeight.w700)), const Spacer(), if(pay!=null) Text('₹${pay.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800))])),
                          const SizedBox(height:8),
                          ElevatedButton.icon(icon: const Icon(Icons.payments_outlined), label: const Text('Mark Paid (Complete Payment)'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white), onPressed: () async {
                            try{
                              await ref.read(apiClientProvider).post('/api/v1/payments/${booking.id}/status', body:{'status':'COMPLETED'});
                              ref.invalidate(_activeBookingProvider);
                              ref.read(queueRefreshProvider.notifier).state++;
                              if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment marked COMPLETED')));
                            }catch(e){ if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyMessage(e)))); }
                          }),
                          const SizedBox(height:4),
                          Text('Tap Mark Paid to credit farmer. Dashboard paymentPending will decrement.', style: TextStyle(fontSize:10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ]);
                      }
                      // For non-completed stages, still show payment status + mark paid if PENDING/PROCESSING
                      if (pay != null && (pay.status == PaymentStatus.pending || pay.status == PaymentStatus.processing)) {
                        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children:[
                          AppCard(child: Row(children:[Icon(Icons.payments, color: pay.status==PaymentStatus.processing? const Color(0xFFEF6C00): const Color(0xFF6A1B9A)), const SizedBox(width:8), Expanded(child: Text('Payment $status • ₹${pay.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700))), StatusChip(label: status, color: pay.status==PaymentStatus.processing? const Color(0xFFEF6C00): const Color(0xFF6A1B9A), icon: Icons.hourglass_top)])),
                          const SizedBox(height:8),
                          OutlinedButton.icon(icon: const Icon(Icons.payments_outlined, size:18), label: const Text('Mark Paid (Complete Payment)'), onPressed: () async {
                            try{
                              await ref.read(apiClientProvider).post('/api/v1/payments/${booking.id}/status', body:{'status':'COMPLETED'});
                              ref.invalidate(_activeBookingProvider);
                              ref.read(queueRefreshProvider.notifier).state++;
                              if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment marked COMPLETED')));
                            }catch(e){ if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyMessage(e)))); }
                          }),
                        ]);
                      }
                      return const SizedBox.shrink();
                    },
                  );
                  // Fetch approval state for button logic
                  return FutureBuilder<Map<String, dynamic>>(
                    future: ref.read(procurementRepositoryProvider).getProcurement(booking.id).catchError((_) => <String,dynamic>{'approval_status':'NONE'}),
                    builder: (context, snap2) {
                      final data2 = snap2.data;
                      final status2 = (data2?['approval_status'] as String?) ?? 'NONE';
                      final pending2 = data2?['pending_stage'] as String?;
                      final stages = ProcurementStage.values;
                      final idx = stages.indexOf(booking.procurementStage);
                      ProcurementStage? nextStage = idx < stages.length - 1 ? stages[idx + 1] : null;

                      // Map backend stage string to ProcurementStage
                      ProcurementStage? pendingStageEnum;
                      if (pending2 != null) {
                        const backendMap = {
                          'BOOKING_CONFIRMED': ProcurementStage.bookingConfirmed,
                          'ARRIVED': ProcurementStage.arrivedAtCentre,
                          'WEIGHMENT': ProcurementStage.weighment,
                          'QUALITY_CHECK': ProcurementStage.qualityCheck,
                          'PROCUREMENT': ProcurementStage.procurement,
                          'COMPLETED': ProcurementStage.completed,
                        };
                        pendingStageEnum = backendMap[pending2];
                      }

                      // Operator view
                      if (isOperator) {
                        if (status2 == 'PENDING') {
                          return AppCard(child: Row(children: [const Icon(Icons.hourglass_top, size: 18, color: Color(0xFFEF6C00)), const SizedBox(width: 8), Expanded(child: Text('Awaiting admin approval for ${pending2 ?? nextStage?.name ?? ""}', style: const TextStyle(fontSize: 12, color: Color(0xFFEF6C00))))]));
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ComplianceQACard(booking: booking),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.send, size: 18),
                              label: const Text('Request Approval'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
                              onPressed: nextStage == null ? null : () async {
                                try {
                                  await ref.read(procurementRepositoryProvider).advanceStage(booking.id, nextStage);
                                  ref.invalidate(_activeBookingProvider);
                                  if (context.mounted) {
                                    final msg = (booking.quantityQuintal > 50) ? 'Approval requested — pending admin ( >50 quintal / >₹1L )' : 'Approval requested — pending admin';
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                                  }
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyMessage(e))));
                                }
                              },
                            ),
                            const SizedBox(height: 6),
                            const Text('Operator proposes next stage; admin (9999999999) approves final COMPLETED. >50 quintal or >₹1L requires admin.', style: TextStyle(fontSize: 10, color: Color(0xFF6A1B9A))),
                          ],
                        );
                      }
                      // Admin view
                      if (isAdmin) {
                        if (status2 == 'PENDING' && pendingStageEnum != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ComplianceQACard(booking: booking),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.verified, size: 18),
                                label: Text('Approve ${pending2 ?? ""}'),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                                onPressed: () async {
                                  try {
                                    await ref.read(procurementRepositoryProvider).approveStage(booking.id, pendingStageEnum!);
                                    ref.invalidate(_activeBookingProvider);
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved by admin')));
                                  } catch (e) {
                                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyMessage(e))));
                                  }
                                },
                              ),
                            ],
                          );
                        }
                        // Admin can also directly advance if no pending
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ComplianceQACard(booking: booking),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: const Text('Advance to Next Stage (Admin)'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                              onPressed: nextStage == null ? null : () async {
                                try {
                                  await ref.read(procurementRepositoryProvider).advanceStage(booking.id, nextStage);
                                  ref.invalidate(_activeBookingProvider);
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stage advanced by admin')));
                                } catch (e) {
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyMessage(e))));
                                }
                              },
                            ),
                            if (status2 == 'ADMIN_APPROVED') const Padding(padding: EdgeInsets.only(top: 6), child: Text('Last action admin approved', style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32)))),
                          ],
                        );
                      }
                      return const SizedBox();
                    },
                  );
                }),
              ]);
            },
          );
        },
      ),
    );
  }
}

/// P1 Compliance Agent light — interactive Q&A before approval.
/// Lightweight deterministic: calls POST /api/v1/procurements/{id}/compliance-check
/// Rule: Grade B + answer mentions ISO/moisture => verified. No ML.
class _ComplianceQACard extends ConsumerStatefulWidget {
  final Booking booking;
  const _ComplianceQACard({required this.booking});
  @override
  ConsumerState<_ComplianceQACard> createState() => _ComplianceQACardState();
}

class _ComplianceQACardState extends ConsumerState<_ComplianceQACard> {
  final _qCtrl = TextEditingController(text: 'Why Grade B not A?');
  final _aCtrl = TextEditingController();
  bool _loading = false;
  ComplianceResult? _result;
  String? _error;

  @override
  void dispose() {
    _qCtrl.dispose();
    _aCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_qCtrl.text.trim().isEmpty || _aCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Both question and answer required.');
      return;
    }
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final res = await ref.read(procurementRepositoryProvider).complianceCheck(widget.booking.id, _qCtrl.text.trim(), _aCtrl.text.trim());
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = userFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.verified_user, size: 18, color: AppTheme.primaryGreen)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Compliance Q&A', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text('procureflow.ai Agent — verify justification vs booking data', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2))),
            child: const Text('P1 LIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen))),
        ]),
        const SizedBox(height: 12),
        Text('Booking: ${widget.booking.commodity} • ${widget.booking.quantityQuintal}q • ${widget.booking.tokenNumber}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 10),
        TextField(
          controller: _qCtrl,
          decoration: const InputDecoration(labelText: 'Question', hintText: 'Why Grade B not A?', prefixIcon: Icon(Icons.help_outline, size: 18)),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _aCtrl,
          maxLines: 3,
          minLines: 2,
          decoration: const InputDecoration(
            labelText: 'Answer (operator justification)',
            hintText: 'e.g. Grade B — moisture 17% as per ISO 24531, within TNCSC FAQ...',
            alignLabelWithHint: true,
          ),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _verify,
            icon: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline, size: 18),
            label: Text(_loading ? 'Verifying...' : 'Verify'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.error.withValues(alpha: 0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.error_outline, size: 16, color: AppTheme.error), const SizedBox(width: 8), Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppTheme.error)))])),
        ],
        if (_result != null) ...[
          const SizedBox(height: 12),
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(
            color: _result!.verified ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _result!.verified ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.warning.withValues(alpha: 0.3)),
          ), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_result!.verified ? Icons.verified : Icons.warning_amber_rounded, size: 18, color: _result!.verified ? AppTheme.success : AppTheme.warning),
              const SizedBox(width: 6),
              Text(_result!.verified ? 'VERIFIED' : 'NEEDS REVIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _result!.verified ? AppTheme.success : AppTheme.warning)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Text('${_result!.commodity} • ${_result!.quantity}q • Grade ${_result!.grade ?? "PENDING"} • Moisture ${_result!.moisture != null ? "${_result!.moisture}%" : "—"}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary))),
            ]),
            const SizedBox(height: 8),
            Text(_result!.reason, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _result!.verified ? AppTheme.success : AppTheme.warning)),
            const SizedBox(height: 8),
            Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
              child: SelectableText(_result!.generatedJustification, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4))),
            const SizedBox(height: 6),
            const Text('Audit-ready text — copy for TNCSC records.', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
          ])),
        ],
        const SizedBox(height: 6),
        const Text('Deterministic, no ML. Grade B + ISO/moisture in answer ⇒ verified.', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ]),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final TimelineStep step;
  const _TimelineTile({required this.step});
  @override
  Widget build(BuildContext context) {
    final color = step.isCompleted? const Color(0xFF2E7D32): step.isCurrent? const Color(0xFFEF6C00): Colors.grey;
    final icon = step.isCompleted? Icons.check_circle: step.isCurrent? Icons.sync: Icons.radio_button_unchecked;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical:8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width:12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(step.title, style: TextStyle(fontWeight: FontWeight.w600, color: step.isCurrent||step.isCompleted? Theme.of(context).colorScheme.onSurface: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(step.subtitle, style: TextStyle(fontSize:12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (step.timestamp != null) Text(AppDateUtils.formatTime(step.timestamp!), style: const TextStyle(fontSize:11, color: Color(0xFF2E7D32))),
        ])),
        if (step.isCurrent) Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:4), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(20)), child: const Text('IN PROGRESS', style: TextStyle(fontSize:10, fontWeight: FontWeight.w700, color: Color(0xFFEF6C00)))),
        if (step.isCompleted) const Icon(Icons.done, size:16, color: Color(0xFF2E7D32)),
      ]),
    );
  }
}

final _activeBookingProvider = FutureProvider<Booking?>((ref) async {
  final auth = await ref.read(authRepositoryProvider).getCurrentUser();
  if (auth==null) return null;
  return ref.watch(slotRepositoryProvider).getActiveBooking(auth.id);
});
