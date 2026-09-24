import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/location/location_service.dart';
import '../../../core/storage/local_storage.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/providers.dart';
import '../../../models/centre.dart';

class CentresScreen extends ConsumerStatefulWidget {
  const CentresScreen({super.key});
  @override
  ConsumerState<CentresScreen> createState() => _CentresScreenState();
}

class _CentresScreenState extends ConsumerState<CentresScreen> {
  double? lat;
  double? lng;
  double radiusKm = 20;
  String? commodity; // null = All
  String? district;
  bool showMap = false;
  bool locLoading = true;
  String? locError;
  bool isManual = false;
  bool centresLoading = true;
  String? centresError;
  List<ProcurementCentre> centres = [];
  DateTime? lastUpdated;
  bool isOffline = false;
  // recommendation
  String? recommendedCentreId;
  String? recommendedReason;
  Map<String, dynamic>? recommendedDebug;
  Timer? _pollTimer;

  static const commodities = ['All', 'Paddy', 'Ragi', 'Wheat', 'Millet', 'Onion', 'Pulses'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final s = LocalStorage.instance;
    radiusKm = double.tryParse(s.getString('centres_radius') ?? '') ?? 20;
    commodity = s.getString('centres_commodity');
    if (commodity != null && commodity!.isEmpty) commodity = null;
    district = s.getString('centres_district');
    showMap = s.getString('centres_showMap') == 'true';
    await _requestLocationAndFetch();
    // live polling every 30s for queue/capacity
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _silentRefresh();
    });
  }

  Future<void> _silentRefresh() async {
    try {
      final repo = ref.read(centreRepositoryProvider);
      final list = await repo.getNearbyCentres(lat: lat, lng: lng, radiusKm: radiusKm, commodity: commodity, district: district).timeout(const Duration(seconds: 15));
      // also refresh recommendation silently
      Map<String, dynamic>? rec;
      try {
        rec = await repo.getRecommendations(lat: lat, lng: lng, radiusKm: radiusKm, commodity: commodity, district: district, estimatedQuantity: 10).timeout(const Duration(seconds: 10));
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        centres = list;
        lastUpdated = DateTime.now();
        isOffline = false;
        if (rec != null && rec['ranked'] is List && (rec['ranked'] as List).isNotEmpty) {
          final top = (rec['ranked'] as List).first as Map<String, dynamic>;
          recommendedCentreId = (top['centre'] as Map)['id'] as String?;
          recommendedReason = top['reason'] as String?;
          recommendedDebug = top['debug'] as Map<String, dynamic>?;
        }
      });
    } catch (_) {}
  }

  Future<void> _requestLocationAndFetch() async {
    setState(() { locLoading = true; locError = null; });
    final cachedLoc = LocationService.instance.getCachedLocation();
    if (cachedLoc != null && cachedLoc.hasLocation) {
      lat = cachedLoc.lat; lng = cachedLoc.lng; isManual = cachedLoc.isManual;
    }
    final res = await LocationService.instance.requestAndGetLocation();
    if (res.hasLocation) {
      lat = res.lat; lng = res.lng; isManual = res.isManual; locError = null;
    } else {
      if (lat == null || lng == null) {
        lat = LocationService.fallbackLat; lng = LocationService.fallbackLng; isManual = false;
        if (res.error != null) locError = '${res.error} Showing Erode centres.';
        else locError = 'Using Erode fallback location.';
      } else {
        locError = res.error;
      }
      if (res.state == LocationPermissionState.permanentlyDenied) {
        locError = 'Location permission denied. Enable from settings or use fallback. Showing Erode.';
      } else if (res.state == LocationPermissionState.serviceDisabled) {
        locError = 'GPS disabled. Enable location or use fallback. Showing Erode.';
      }
    }
    setState(() => locLoading = false);
    await _fetchCentres();
  }

  Future<void> _fetchCentres() async {
    setState(() { centresLoading = true; centresError = null; });
    try {
      final repo = ref.read(centreRepositoryProvider);
      final list = await repo.getNearbyCentres(lat: lat, lng: lng, radiusKm: radiusKm, commodity: commodity, district: district).timeout(const Duration(seconds: 20));
      // recommendations ranked
      Map<String, dynamic>? rec;
      try {
        rec = await repo.getRecommendations(lat: lat, lng: lng, radiusKm: radiusKm, commodity: commodity, district: district, estimatedQuantity: 10).timeout(const Duration(seconds: 10));
      } catch (_) {}
      final s = LocalStorage.instance;
      await s.setString('centres_cache_lat', lat.toString());
      await s.setString('centres_cache_lng', lng.toString());
      await s.setString('centres_cache_time', DateTime.now().toIso8601String());
      setState(() {
        centres = list;
        centresLoading = false;
        lastUpdated = DateTime.now();
        isOffline = false;
        if (rec != null && rec['ranked'] is List && (rec['ranked'] as List).isNotEmpty) {
          final top = (rec['ranked'] as List).first as Map<String, dynamic>;
          recommendedCentreId = (top['centre'] as Map)['id'] as String?;
          recommendedReason = top['reason'] as String?;
          recommendedDebug = top['debug'] as Map<String, dynamic>?;
          // Reorder centres to put recommended first if not already
          if (recommendedCentreId != null) {
            centres.sort((a, b) {
              if (a.id == recommendedCentreId) return -1;
              if (b.id == recommendedCentreId) return 1;
              // fallback distance sort
              final da = a.distanceKm ?? 999;
              final db = b.distanceKm ?? 999;
              return da.compareTo(db);
            });
          }
        } else {
          recommendedCentreId = null;
          recommendedReason = null;
        }
      });
    } catch (e) {
      setState(() {
        centresLoading = false;
        centresError = e.toString().replaceAll('Exception:', '').trim();
        isOffline = true;
      });
    }
  }

  String _updatedAgo() {
    if (lastUpdated == null) return '';
    final d = DateTime.now().difference(lastUpdated!);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Future<void> _openManualDialog() async {
    final latCtrl = TextEditingController(text: lat?.toStringAsFixed(4) ?? LocationService.fallbackLat.toString());
    final lngCtrl = TextEditingController(text: lng?.toStringAsFixed(4) ?? LocationService.fallbackLng.toString());
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Enter location'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: latCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Latitude')),
        const SizedBox(height: 8),
        TextField(controller: lngCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'Longitude')),
        const SizedBox(height: 8),
        const Text('Example: Erode 11.3410, 77.7172', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Use this')),
      ],
    ));
    if (ok == true) {
      final nlat = double.tryParse(latCtrl.text.trim());
      final nlng = double.tryParse(lngCtrl.text.trim());
      if (nlat != null && nlng != null && nlat >= -90 && nlat <= 90 && nlng >= -180 && nlng <= 180) {
        final res = await LocationService.instance.manualLocation(lat: nlat, lng: nlng);
        setState(() { lat = res.lat; lng = res.lng; isManual = true; locError = null; });
        await _fetchCentres();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.centres),
        actions: [
          IconButton(icon: Icon(showMap ? Icons.list : Icons.map), tooltip: showMap ? 'List view' : 'Map view', onPressed: () async {
            setState(() => showMap = !showMap);
            await LocalStorage.instance.setString('centres_showMap', showMap.toString());
          }),
          IconButton(icon: const Icon(Icons.my_location), tooltip: 'My location', onPressed: _requestLocationAndFetch),
        ],
      ),
      body: Column(children: [
        if (locLoading)
          const LinearProgressIndicator(minHeight: 2)
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: locError != null ? AppTheme.warning.withValues(alpha: 0.12) : AppTheme.primaryGreen.withValues(alpha: 0.08),
            child: Row(children: [
              Icon(locError != null ? Icons.location_off : Icons.near_me, size: 16, color: locError != null ? AppTheme.warning : AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Expanded(child: Text(
                locError ?? (isManual ? 'Manual location ${lat?.toStringAsFixed(3)}, ${lng?.toStringAsFixed(3)}' : 'Near you ${lat?.toStringAsFixed(3)}, ${lng?.toStringAsFixed(3)} • ${radiusKm.toInt()} km'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: locError != null ? AppTheme.warning : AppTheme.primaryGreen),
                maxLines: 2,
              )),
              if (locError != null) ...[
                TextButton(onPressed: () => LocationService.instance.openSettings(), child: const Text('Settings', style: TextStyle(fontSize: 11))),
                TextButton(onPressed: _openManualDialog, child: const Text('Manual', style: TextStyle(fontSize: 11))),
              ] else
                TextButton(onPressed: _openManualDialog, child: const Text('Change', style: TextStyle(fontSize: 11))),
            ]),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          color: Theme.of(context).cardColor,
          child: Column(children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                const Text('Commodity:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                ...commodities.map((c) {
                  final selected = (c == 'All' && commodity == null) || c == commodity;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(c, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      onSelected: (v) async {
                        final newVal = c == 'All' ? null : c;
                        setState(() => commodity = newVal);
                        await LocalStorage.instance.setString('centres_commodity', newVal ?? '');
                        if (newVal == null) await LocalStorage.instance.remove('centres_commodity');
                        await _fetchCentres();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Radius:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              ...[5, 10, 20, 50].map((r) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('${r}km', style: const TextStyle(fontSize: 12)),
                  selected: radiusKm == r.toDouble(),
                  onSelected: (v) async {
                    setState(() => radiusKm = r.toDouble());
                    await LocalStorage.instance.setString('centres_radius', r.toString());
                    await _fetchCentres();
                  },
                  visualDensity: VisualDensity.compact,
                ),
              )),
              const Spacer(),
              if (lastUpdated != null)
                Text(isOffline ? 'Offline • ${_updatedAgo()}' : 'Updated ${_updatedAgo()}', style: TextStyle(fontSize: 11, color: isOffline ? AppTheme.warning : AppTheme.textSecondary)),
            ]),
          ]),
        ),
        // Recommendation banner
        if (recommendedCentreId != null && recommendedReason != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.star, size: 16, color: Colors.white)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Recommended for you', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.primaryGreen)),
                const SizedBox(height: 2),
                Text(recommendedReason!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                if (recommendedDebug != null)
                  Text('Score debug: dist ${recommendedDebug!['dist_norm']} • queue ${recommendedDebug!['queue_norm']} • occ ${recommendedDebug!['occ']} • boost ${recommendedDebug!['farmer_past'] != null ? 'history' : 'none'}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ])),
              TextButton(onPressed: () {
                final idx = centres.indexWhere((c) => c.id == recommendedCentreId);
                if (idx != -1) {
                  // scroll is handled by list; just highlight via snackbar
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Top pick: ${centres[idx].name}')));
                }
              }, child: const Text('View', style: TextStyle(fontSize: 12))),
            ]),
          ),
        const Divider(height: 1),
        Expanded(
          child: centresLoading
              ? const Center(child: CircularProgressIndicator())
              : centresError != null && centres.isEmpty
                  ? _ErrorView(message: centresError!, onRetry: _fetchCentres)
                  : centres.isEmpty
                      ? _EmptyView(commodity: commodity, radiusKm: radiusKm)
                      : RefreshIndicator(
                          onRefresh: _fetchCentres,
                          child: showMap ? _MapAndList(
                            centres: centres,
                            userLat: lat, userLng: lng,
                            recommendedId: recommendedCentreId,
                            onTapCentre: (c) => context.push('/centres/${c.id}?lat=${lat ?? ''}&lng=${lng ?? ''}'),
                          ) : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: centres.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final c = centres[i];
                              final isRecommended = c.id == recommendedCentreId;
                              return _CentreCard(
                                centre: c,
                                isRecommended: isRecommended,
                                recommendedReason: isRecommended ? recommendedReason : null,
                                onTapDetails: () => context.push('/centres/${c.id}?lat=${lat ?? ''}&lng=${lng ?? ''}'),
                                onTapNavigate: () => _navigateTo(c),
                                onTapBook: () => context.push('/slots?centreId=${c.id}&centreName=${Uri.encodeComponent(c.name)}'),
                              );
                            },
                          ),
                        ),
        ),
      ]),
    );
  }

  Future<void> _navigateTo(ProcurementCentre c) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lng}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final geo = Uri.parse('geo:${c.lat},${c.lng}?q=${c.lat},${c.lng}(${Uri.encodeComponent(c.name)})');
      if (await canLaunchUrl(geo)) await launchUrl(geo);
    }
  }
}

class _MapAndList extends StatelessWidget {
  final List<ProcurementCentre> centres;
  final double? userLat;
  final double? userLng;
  final String? recommendedId;
  final void Function(ProcurementCentre) onTapCentre;
  const _MapAndList({required this.centres, this.userLat, this.userLng, this.recommendedId, required this.onTapCentre});

  @override
  Widget build(BuildContext context) {
    final userPos = (userLat != null && userLng != null) ? LatLng(userLat!, userLng!) : null;
    final centre = centres.isNotEmpty ? centres.first : null;
    final initial = userPos ?? (centre != null ? LatLng(centre.lat, centre.lng) : const LatLng(11.3410, 77.7172));
    final markers = <Marker>{
      if (userPos != null)
        Marker(markerId: const MarkerId('me'), position: userPos, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), infoWindow: const InfoWindow(title: 'You')),
      for (final c in centres)
        Marker(
          markerId: MarkerId(c.id),
          position: LatLng(c.lat, c.lng),
          infoWindow: InfoWindow(title: c.name + (c.id == recommendedId ? ' ⭐ Recommended' : ''), snippet: c.distanceKm != null ? '${c.distanceKm!.toStringAsFixed(1)} km • ${c.status}' : c.status),
          onTap: () => onTapCentre(c),
          icon: c.id == recommendedId ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow) : (c.isOpen ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen) : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)),
        ),
    };
    return Column(children: [
      SizedBox(
        height: 260,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: initial, zoom: 11),
          markers: markers,
          myLocationEnabled: userPos != null,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: true,
        ),
      ),
      const Divider(height: 1),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: centres.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final c = centres[i];
            return _CentreCard(
              centre: c,
              isRecommended: c.id == recommendedId,
              onTapDetails: () => onTapCentre(c),
              onTapNavigate: () async {
                final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lng}');
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              onTapBook: () => context.push('/slots?centreId=${c.id}&centreName=${Uri.encodeComponent(c.name)}'),
            );
          },
        ),
      ),
    ]);
  }
}

class _CentreCard extends StatelessWidget {
  final ProcurementCentre centre;
  final bool isRecommended;
  final String? recommendedReason;
  final VoidCallback onTapDetails;
  final VoidCallback onTapNavigate;
  final VoidCallback onTapBook;
  const _CentreCard({required this.centre, this.isRecommended = false, this.recommendedReason, required this.onTapDetails, required this.onTapNavigate, required this.onTapBook});
  @override
  Widget build(BuildContext context) {
    final isOpen = centre.isOpen;
    return AppCard(
      child: InkWell(
        onTap: onTapDetails,
        borderRadius: BorderRadius.circular(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isRecommended)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFC107))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star, size: 14, color: Color(0xFFFF8F00)),
                const SizedBox(width: 4),
                const Text('Recommended for you', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFFF8F00))),
                if (recommendedReason != null) ...[
                  const SizedBox(width: 6),
                  Flexible(child: Text(recommendedReason!, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis)),
                ],
              ]),
            ),
          Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isRecommended ? const Color(0xFFFFF8E1) : AppTheme.primaryGreen.withValues(alpha:0.12), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.store, color: isRecommended ? const Color(0xFFFF8F00) : AppTheme.primaryGreen, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(centre.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(centre.location, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha:0.7) ?? Colors.black54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (centre.centreCode != null) Text(centre.centreCode!, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ])),
            StatusChip(label: centre.status.toUpperCase(), color: isOpen ? AppTheme.success : AppTheme.warning, icon: isOpen ? Icons.check_circle : Icons.pause_circle),
          ]),
          const SizedBox(height: 8),
          if (centre.distanceKm != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha:0.08), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.near_me, size: 14, color: AppTheme.primaryGreen),
                const SizedBox(width: 4),
                Text('${centre.distanceKm!.toStringAsFixed(1)} km away', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                if (centre.dailyCapacity != null && centre.remainingCapacityToday != null) ...[
                  const Text('  •  ', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  Text('${centre.remainingCapacityToday} / ${centre.dailyCapacity} left', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
          const SizedBox(height: 8),
          Row(children: [
            _StatChip(icon: Icons.groups, label: 'Queue ${centre.currentQueue}'),
            const SizedBox(width: 6),
            _StatChip(icon: Icons.schedule, label: '${centre.estimatedWaitMinutes} min'),
            const SizedBox(width: 6),
            _StatChip(icon: Icons.event_available, label: '${centre.availableSlots} slots'),
            const Spacer(),
            if (centre.phone != null) IconButton(icon: const Icon(Icons.phone, size: 18, color: AppTheme.primaryGreen), onPressed: () async {
              final uri = Uri.parse('tel:${centre.phone}');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            }, tooltip: centre.phone, visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing:6, runSpacing: 4, children: centre.commodities.map((e) => Chip(label: Text(e, style: const TextStyle(fontSize:11)), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: const EdgeInsets.symmetric(horizontal: 6))).toList()),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.navigation, size:16), label: const Text('Navigate', style: TextStyle(fontSize: 13)), onPressed: onTapNavigate)),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.info_outline, size:16), label: const Text('Details', style: TextStyle(fontSize: 13)), onPressed: onTapDetails)),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.calendar_today, size:16), label: const Text('Book', style: TextStyle(fontSize: 13)), onPressed: onTapBook)),
          ]),
        ]),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E352E) : const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF3E4A3E) : const Color(0xFFD0E8D0)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: isDark ? const Color(0xFF81C784) : AppTheme.primaryGreen),
        const SizedBox(width:3),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.textPrimary)),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 48, color: AppTheme.textSecondary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: onRetry),
      ]),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  final String? commodity;
  final double radiusKm;
  const _EmptyView({this.commodity, required this.radiusKm});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary),
        const SizedBox(height: 12),
        Text('No centres found within ${radiusKm.toInt()} km${commodity != null ? " for $commodity" : ""}.', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Try increasing radius or changing commodity filter.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary), textAlign: TextAlign.center),
      ]),
    ),
  );
}
