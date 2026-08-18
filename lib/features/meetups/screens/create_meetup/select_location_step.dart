import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/places/place_result.dart';
import '../../../../core/places/places_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/map/center_pin.dart';
import '../../../../core/widgets/map/lat_lng.dart';
import '../../../../core/widgets/map/locate_me_button.dart';
import '../../../../core/widgets/map/google_map_widget.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../meetups_controller.dart';
import '../../models/meetup_location.dart';

/// Step 1 of the Create Meetup wizard: a pin fixed at the screen's center
/// marks the venue - search (via Nominatim/OSM geocoding) or drag the map
/// underneath the pin to move it, each settling reverse-geocoded via
/// [_onCenterChanged].
class SelectLocationStep extends StatefulWidget {
  const SelectLocationStep({super.key, required this.onConfirmed});

  /// Called after the chosen location has been written to the draft, so the
  /// wizard shell can advance to step 2.
  final VoidCallback onConfirmed;

  @override
  State<SelectLocationStep> createState() => _SelectLocationStepState();
}

class _SelectLocationStepState extends State<SelectLocationStep> {
  static const _defaultCenter = LatLng(13.7563, 100.5018);

  // Nominatim's usage policy caps public-instance traffic at ~1 req/sec -
  // debounce keystrokes rather than searching on every change.
  static const _searchDebounce = Duration(milliseconds: 500);

  final _searchController = TextEditingController();
  final _mapController = MapCenterController();
  Timer? _debounceTimer;
  String _query = '';
  List<PlaceResult> _results = [];
  bool _searching = false;
  bool _resolvingCenter = false;
  bool _locating = false;
  MeetupLocation? _selected;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
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
  Future<void> _onCenterChanged(LatLng point) async {
    setState(() => _resolvingCenter = true);
    final place = await context.read<PlacesRepository>().reverseGeocode(point);
    if (!mounted) return;
    setState(() {
      _resolvingCenter = false;
      _selected = MeetupLocation(
        name: place?.name ?? 'ตำแหน่งที่เลือก',
        address: place?.address ??
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        position: point,
      );
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

  void _confirm() {
    final location = _selected;
    if (location == null) return;
    context.read<MeetupsController>().setDraftLocation(location);
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final showResults = _query.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (_selected != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_selected!.name, style: AppTextStyles.titleMd),
        ],
        const SizedBox(height: AppSpacing.lg),
        PillButton(
          label: 'ยืนยันสถานที่',
          onPressed: _selected == null ? null : _confirm,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
