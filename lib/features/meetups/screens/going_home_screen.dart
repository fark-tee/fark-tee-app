import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/map/lat_lng.dart';
import '../../../core/widgets/pill_button.dart';
import '../meetups_controller.dart';

class _SavedDestination {
  const _SavedDestination(this.name, this.address, this.position);

  final String name;
  final String address;
  final LatLng position;
}

/// Mock saved locations shown inline per the spec's own example content -
/// no separate "choose destination" screen.
const _savedDestinations = [
  _SavedDestination(
    'Home (Default)',
    'Ratchada 7, Ratchada, Bangkok',
    LatLng(13.7649, 100.5383),
  ),
  _SavedDestination(
    'Condo',
    'Ratchada 7, Ratchada, Bangkok',
    LatLng(13.7649, 100.5383),
  ),
];

/// Lets the current user announce they're heading home from a meetup,
/// picking one of a couple of saved destinations, then reports the status
/// change via `MeetupsController.goHome` and clears the meetup stack.
class GoingHomeScreen extends StatefulWidget {
  const GoingHomeScreen({super.key, required this.meetupId});

  final String meetupId;

  @override
  State<GoingHomeScreen> createState() => _GoingHomeScreenState();
}

class _GoingHomeScreenState extends State<GoingHomeScreen> {
  bool _loading = false;
  String _selectedDestination = _savedDestinations.first.name;

  Future<void> _confirmGoingHome() async {
    setState(() => _loading = true);

    final controller = context.read<MeetupsController>();
    final messenger = ScaffoldMessenger.of(context);
    final destination = _savedDestinations.firstWhere(
      (d) => d.name == _selectedDestination,
    );
    final succeeded = await controller.goHome(
      widget.meetupId,
      destinationLabel: destination.name,
      destinationPosition: destination.position,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!succeeded) {
      if (controller.errorMessage != null) {
        messenger.showSnackBar(SnackBar(content: Text(controller.errorMessage!)));
      }
      return;
    }

    context.go('/home');
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
              Text('Heading home?', style: AppTextStyles.displayLg),
              const SizedBox(height: AppSpacing.xs),
              Text(
                "Let your friends know you're on your way home",
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Choose a new destination', style: AppTextStyles.titleMd),
              const SizedBox(height: AppSpacing.md),
              for (final destination in _savedDestinations) ...[
                _DestinationCard(
                  destination: destination,
                  selected: destination.name == _selectedDestination,
                  onTap: () =>
                      setState(() => _selectedDestination = destination.name),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const Spacer(),
              PillButton(
                label: 'Confirm Going Home',
                loading: _loading,
                onPressed: _confirmGoingHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _SavedDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.name,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(destination.address, style: AppTextStyles.captionMd),
              ],
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: AppColors.textPrimary),
        ],
      ),
    );
  }
}
