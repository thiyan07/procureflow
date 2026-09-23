import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../services/providers.dart';
import '../../../core/network/api_error.dart';
import '../../../core/constants/app_constants.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});
  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _handled = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null) return;
    String bookingId = '';
    if (raw.startsWith('PROCUREFLOW|')) {
      final parts = raw.split('|');
      if (parts.length >= 2) bookingId = parts[1];
    } else {
      bookingId = raw.trim();
    }
    if (bookingId.isEmpty) return;
    _handled = true;
    controller.stop();
    try {
      await ref.read(queueRepositoryProvider).updateQueueStatus(bookingId, QueueStatus.arrived);
      ref.read(queueRefreshProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Arrived marked for $bookingId')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      try {
        await ref.read(apiClientProvider).post('/api/v1/queue/$bookingId/transition', body: {'to_status': 'ARRIVED'});
        ref.read(queueRefreshProvider.notifier).state++;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Arrived marked for $bookingId')));
          Navigator.of(context).pop(true);
        }
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyMessage(e2))));
          _handled = false;
          controller.start();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR — Mark Arrived')),
      body: Column(children: [
        Expanded(
          flex: 4,
          child: MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Column(children: [
              const Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              const Text('Point camera at farmer QR (My Token)', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 4),
              Text('PROCUREFLOW|bookingId|token|centre', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                icon: const Icon(Icons.flash_on),
                label: const Text('Toggle Torch'),
                onPressed: () => controller.toggleTorch(),
              ),
            ]),
          ),
        ),
      ]      ),
    );
  }
}
