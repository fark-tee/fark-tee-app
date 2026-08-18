import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_service.dart';
import '../../../core/places/place_result.dart';
import '../../../core/places/places_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/map/center_pin.dart';
import '../../../core/widgets/map/google_map_widget.dart';
import '../../../core/widgets/map/lat_lng.dart';
import '../../../core/widgets/map/locate_me_button.dart';
import '../../../core/widgets/pill_button.dart';
import '../data/saved_locations_repository.dart';

/// Lets the user save a new destination (POST /v1/saved-locations). A pin
/// fixed at the screen's center marks the spot - search (via Nominatim/OSM
/// geocoding) or drag the map underneath the pin to move it, each settling
/// reverse-geocoded via [_onCenterChanged] - plus a name field since a saved
/// location needs a user-chosen label ("บ้าน", "ที่ทำงาน", ...) that a place
/// search result doesn't provide on its own.
class AddSavedLocationScreen extends StatefulWidget {
  const AddSavedLocationScreen({super.key});

  @override
  State<AddSavedLocationScreen> createState() => _AddSavedLocationScreenState();
}

class _AddSavedLocationScreenState extends State<AddSavedLocationScreen> {
  static const _defaultCenter = LatLng(13.7563, 100.5018);

  // Nominatim's usage policy caps public-instance traffic at ~1 req/sec -
  // debounce keystrokes rather than searching on every change.
  static const _searchDebounce = Duration(milliseconds: 500);

  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _mapController = MapCenterController();
  Timer? _debounceTimer;
  String _query = '';
  List<PlaceResult> _results = [];
  bool _searching = false;
  bool _resolvingCenter = false;
  bool _saving = false;
  bool _locating = false;
  PlaceResult? _selected;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounceTimer = Timer(_searchDebounce, () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    final results = await context.read<PlacesRepository>().search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  /// Selecting a search result just moves the camera - the pin stays fixed
  /// on screen, so [_onCenterChanged] is what actually records the pick once
  /// the camera settles there.
  void _select(PlaceResult place) {
    setState(() {
      _query = '';
      _results = [];
      _searchController.clear();
    });
    _mapController.moveTo(place.position);
  }

  /// Fired whenever the camera settles - after a drag, a tap, a search pick,
  /// or "find me" - with whatever point is now under the fixed center pin.
  /// Wherever the pin stops, the name field follows it - always overwritten
  /// with that spot's name, not just filled in when empty.
  Future<void> _onCenterChanged(LatLng point) async {
    setState(() => _resolvingCenter = true);
    final place = await context.read<PlacesRepository>().reverseGeocode(point);
    if (!mounted) return;
    setState(() {
      _resolvingCenter = false;
      _selected = place ??
          PlaceResult(
            name: 'ตำแหน่งที่เลือก',
            address:
                '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
            position: point,
          );
      _nameController.text = _selected!.name;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final position = await context.read<LocationService>().getCurrentPosition();
      if (!mounted) return;
      await _mapController.moveTo(position);
    } on LocationServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final selected = _selected;
    final name = _nameController.text.trim();
    if (selected == null || name.isEmpty) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await context.read<SavedLocationsRepository>().create(
        name: name,
        lat: selected.position.latitude,
        lng: selected.position.longitude,
      );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('บันทึกสถานที่แล้ว')));
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('บันทึกสถานที่ไม่สำเร็จ กรุณาลองใหม่')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showResults = _query.trim().isNotEmpty;
    final canSave = !_saving && _selected != null && _nameController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: AppColors.textPrimary,
                      size: 18,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text('เพิ่มสถานที่บันทึกไว้', style: AppTextStyles.displayLg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('ชื่อสถานที่', style: AppTextStyles.titleMd),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderSubtle, width: 0.6),
                ),
                child: TextField(
                  controller: _nameController,
                  style: AppTextStyles.bodyMd,
                  decoration: InputDecoration(
                    hintText: 'เช่น บ้าน, ที่ทำงาน',
                    hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('เลือกตำแหน่งบนแผนที่', style: AppTextStyles.titleMd),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.borderSubtle, width: 0.6),
                ),
                child: TextField(
                  controller: _searchController,
                  style: AppTextStyles.bodyMd,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาสถานที่',
                    hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  ),
                  onChanged: _onQueryChanged,
                ),
              ),
              if (showResults) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderSubtle, width: 0.6),
                  ),
                  child: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : _results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text('ไม่พบสถานที่', style: AppTextStyles.captionMd),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          itemCount: _results.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: AppColors.borderSubtle),
                          itemBuilder: (context, index) {
                            final place = _results[index];
                            return ListTile(
                              dense: true,
                              title: Text(place.name, style: AppTextStyles.bodyMd),
                              subtitle: Text(
                                place.address,
                                style: AppTextStyles.captionMd,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _select(place),
                            );
                          },
                        ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GoogleMapWidget(
                        center: _defaultCenter,
                        onCenterChanged: _onCenterChanged,
                        centerController: _mapController,
                      ),
                      const CenterPin(),
                      if (_resolvingCenter)
                        const Positioned(
                          top: AppSpacing.sm,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      Positioned(
                        right: AppSpacing.sm,
                        bottom: AppSpacing.sm,
                        child: LocateMeButton(
                          loading: _locating,
                          onPressed: _useCurrentLocation,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PillButton(
                label: 'บันทึกสถานที่',
                loading: _saving,
                onPressed: canSave ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
