import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../../saved_locations/data/saved_locations_repository.dart';
import '../../saved_locations/models/saved_location.dart';
import '../meetups_controller.dart';

/// Lets the current user announce they're heading home from a meetup,
/// picking one of their saved locations (GET /v1/saved-locations), then
/// reports the status change via `MeetupsController.goHome` and clears the
/// meetup stack.
class GoingHomeScreen extends StatefulWidget {
  const GoingHomeScreen({super.key, required this.meetupId});

  final String meetupId;

  @override
  State<GoingHomeScreen> createState() => _GoingHomeScreenState();
}

class _GoingHomeScreenState extends State<GoingHomeScreen> {
  bool _loadingDestinations = true;
  String? _loadError;
  List<SavedLocation> _destinations = [];
  String? _selectedId;

  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  Future<void> _loadDestinations() async {
    setState(() {
      _loadingDestinations = true;
      _loadError = null;
    });
    try {
      final destinations = await context.read<SavedLocationsRepository>().list();
      if (!mounted) return;
      setState(() {
        _destinations = destinations;
        _selectedId = destinations.isEmpty ? null : destinations.first.id;
        _loadingDestinations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'โหลดสถานที่บันทึกไว้ไม่สำเร็จ กรุณาลองใหม่';
        _loadingDestinations = false;
      });
    }
  }

  Future<void> _goToAddLocation() async {
    await context.push('/saved-locations/add');
    if (!mounted) return;
    _loadDestinations();
  }

  Future<void> _confirmGoingHome() async {
    final destination = _destinations.firstWhere((d) => d.id == _selectedId);
    setState(() => _confirming = true);

    final controller = context.read<MeetupsController>();
    final messenger = ScaffoldMessenger.of(context);
    final succeeded = await controller.goHome(
      widget.meetupId,
      destinationLabel: destination.name,
      destinationPosition: destination.position,
    );

    if (!mounted) return;
    setState(() => _confirming = false);

    if (!succeeded) {
      if (controller.errorMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(controller.errorMessage!)));
      }
      return;
    }

    // Pop back to the live map (not `context.go('/home')`, which would reset
    // the whole nav stack) so the user can actually see their own "heading
    // home" destination pin and route on it.
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('กำลังจะกลับบ้านหรือ?', style: AppTextStyles.displayLg),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'บอกให้เพื่อนๆรู้ว่าคุณกำลังเดินทางกลับบ้าน',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('เลือกปลายทาง', style: AppTextStyles.titleMd),
                  TextButton.icon(
                    onPressed: _goToAddLocation,
                    style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('เพิ่มสถานที่ใหม่'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(child: _buildDestinationList()),
              const SizedBox(height: AppSpacing.md),
              PillOutlineButton(label: 'ยกเลิก', onPressed: () => context.pop()),
              const SizedBox(height: AppSpacing.sm),
              PillButton(
                label: 'ยืนยันกลับบ้าน',
                loading: _confirming,
                onPressed: _selectedId == null ? null : _confirmGoingHome,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationList() {
    if (_loadingDestinations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            PillOutlineButton(label: 'ลองใหม่', onPressed: _loadDestinations),
          ],
        ),
      );
    }

    if (_destinations.isEmpty) {
      return Center(
        child: Text(
          'ยังไม่มีสถานที่บันทึกไว้ กดปุ่ม "เพิ่มสถานที่ใหม่" ด้านบนเพื่อเพิ่ม',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      children: [
        for (final destination in _destinations) ...[
          _DestinationCard(
            destination: destination,
            selected: destination.id == _selectedId,
            onTap: () => setState(() => _selectedId = destination.id),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final SavedLocation destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              destination.name,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: AppColors.textPrimary),
        ],
      ),
    );
  }
}
