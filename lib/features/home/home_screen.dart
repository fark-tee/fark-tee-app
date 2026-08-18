import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/location/location_service.dart';
import '../../core/places/place_result.dart';
import '../../core/places/places_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/avatar_circle.dart';
import '../../core/widgets/map/lat_lng.dart';
import '../../core/widgets/map/map_marker.dart';
import '../../core/widgets/map/google_map_widget.dart';
import '../meetups/meetups_controller.dart';
import '../meetups/models/meetup.dart';

/// Full-bleed map with a search bar, a floating "Create Meetup" CTA, and (if
/// any meetups are currently active) a bottom card summarizing the first one
/// - matches the top-left frame of the reference screenshot grid.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Bangkok - used only if the device's location can't be resolved (denied
  // permission, disabled services, simulator with no fix, ...).
  static const _fallbackCenter = LatLng(13.7563, 100.5018);

  // Same debounce as the Create Meetup search step - Nominatim's public
  // instance asks for no more than ~1 request/second.
  static const _searchDebounce = Duration(milliseconds: 500);

  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  LatLng? _currentPosition;
  PlaceResult? _searchedPlace;
  List<PlaceResult> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    context.read<MeetupsController>().loadHome();
    _loadCurrentPosition();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPosition() async {
    try {
      final position = await context.read<LocationService>().getCurrentPosition();
      if (!mounted) return;
      setState(() => _currentPosition = position);
    } on LocationServiceException {
      // Falls back to `_fallbackCenter` - no need to interrupt the user with
      // an error just for opening the home map.
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounceTimer = Timer(_searchDebounce, () => _runSearch(value));
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    final results = await context.read<PlacesRepository>().search(query);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  void _selectPlace(PlaceResult place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchedPlace = place;
      _searchResults = [];
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MeetupsController>();
    final activeGroups = controller.activeGroups;
    final hasActiveGroups = activeGroups.isNotEmpty;
    final firstMeetup = hasActiveGroups ? activeGroups.first : null;

    final center =
        _searchedPlace?.position ??
        _currentPosition ??
        firstMeetup?.location.position ??
        _fallbackCenter;
    final markers = [
      for (final meetup in activeGroups)
        MapMarker(
          id: meetup.id,
          position: meetup.location.position,
          type: MapMarkerType.venue,
          label: meetup.location.name,
        ),
      if (_searchedPlace case final place?)
        MapMarker(
          id: 'searched-place',
          position: place.position,
          type: MapMarkerType.venue,
          label: place.name,
          caption: place.address,
        ),
      if (_currentPosition case final position?)
        MapMarker(
          id: 'current-position',
          position: position,
          type: MapMarkerType.member,
          label: 'คุณ',
          isCurrentUser: true,
        ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            // Keyed on the coordinate: `GoogleMapWidget.center` only feeds
            // the platform view's `initialCameraPosition`, so without a key
            // change the underlying native map (which persists across
            // rebuilds) never re-centers when the current-position fetch
            // resolves or a search result is picked.
            child: GoogleMapWidget(
              key: ValueKey('${center.latitude},${center.longitude}'),
              center: center,
              markers: markers,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SearchBar(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        if (controller.loadingHome) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_searching || _searchResults.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _SearchResults(
                        searching: _searching,
                        results: _searchResults,
                        onSelect: _selectPlace,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: hasActiveGroups ? 0 : AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: _CreateMeetupButton(
                      onTap: () => context.push('/create-meetup'),
                    ),
                  ),
                  if (firstMeetup != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: _ActiveGroupsCard(
                        meetup: firstMeetup,
                        activeCount: activeGroups.length,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark, pill-shaped search field wired to [PlacesRepository] via the
/// parent's debounced `onChanged`.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.borderSubtle, width: 0.6),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.textMuted, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTextStyles.bodyMd,
              cursorColor: AppColors.textMuted,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                filled: true,
                fillColor: AppColors.bgElevated,
                hintText: 'ค้นหาที่ตี้',
                hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Search-results dropdown shown under the search bar while a query is
/// in flight or has results - same list styling as the Create Meetup
/// location-search step.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.searching,
    required this.results,
    required this.onSelect,
  });

  final bool searching;
  final List<PlaceResult> results;
  final ValueChanged<PlaceResult> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderSubtle, width: 0.6),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: searching
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
          : results.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('ไม่พบสถานที่', style: AppTextStyles.captionMd),
            )
          : ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              itemCount: results.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.borderSubtle),
              itemBuilder: (context, index) {
                final place = results[index];
                return ListTile(
                  dense: true,
                  title: Text(place.name, style: AppTextStyles.bodyMd),
                  subtitle: Text(
                    place.address,
                    style: AppTextStyles.captionMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSelect(place),
                );
              },
            ),
    );
  }
}

/// Always-visible floating pill CTA, anchored just above the Active Groups
/// card (or above the bottom nav bar when there's no active group).
class _CreateMeetupButton extends StatelessWidget {
  const _CreateMeetupButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('สร้างตี้'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.bgElevated,
          foregroundColor: AppColors.textPrimary,
          shape: const StadiumBorder(
            side: BorderSide(color: AppColors.borderSubtle, width: 0.6),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          elevation: 4,
        ),
      ),
    );
  }
}

/// Bottom-anchored summary of the first active meetup, tapping through
/// straight to its live view (these are already-active meetups).
class _ActiveGroupsCard extends StatelessWidget {
  const _ActiveGroupsCard({required this.meetup, required this.activeCount});

  final Meetup meetup;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final total = meetup.members.length;
    final arrived = meetup.arrivedCount;
    final progress = total == 0 ? 0.0 : arrived / total;
    final subtitle =
        '${formatDayLabel(meetup.startTime)} · ${formatTime12h(meetup.startTime)} · $total people';

    return AppCard(
      onTap: () => context.push('/meetup/${meetup.id}/live'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ตี้ที่กำลังคึกคัก', style: AppTextStyles.titleMd),
              Text('$activeCount ตี้', style: AppTextStyles.captionMd),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meetup.title, style: AppTextStyles.titleMd),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.captionMd),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AvatarStack(
                initialsList: meetup.members.map((m) => m.initials).toList(),
                imageUrls: meetup.members.map((m) => m.profileImageUrl).toList(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.bgSurface,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentDanger),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('ถึงแล้ว $arrived จาก $total คน', style: AppTextStyles.captionMd),
        ],
      ),
    );
  }
}
