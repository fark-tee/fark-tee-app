import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../meetups_controller.dart';
import 'invite_friends_step.dart';
import 'meetup_details_step.dart';
import 'select_location_step.dart';

/// Shell for the 3-step Create Meetup wizard. Owns the current step index
/// and swaps between [SelectLocationStep], [MeetupDetailsStep], and
/// [InviteFriendsStep], all of which write into [MeetupsController]'s draft
/// fields. `app_router.dart` routes `/create-meetup` straight to this
/// widget, so the constructor shape below must stay stable.
class CreateMeetupScreen extends StatefulWidget {
  const CreateMeetupScreen({super.key});

  @override
  State<CreateMeetupScreen> createState() => _CreateMeetupScreenState();
}

class _CreateMeetupScreenState extends State<CreateMeetupScreen> {
  static const _stepTitles = ['Select Location', 'Meetup Details', 'Invite Friends'];

  int _step = 0;

  @override
  void initState() {
    super.initState();
    // Clear out any draft left over from a previous, abandoned attempt.
    context.read<MeetupsController>().resetDraft();
  }

  void _goToStep(int step) => setState(() => _step = step);

  void _handleBack() {
    if (_step > 0) {
      _goToStep(_step - 1);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: _WizardHeader(
                  step: _step,
                  title: _stepTitles[_step],
                  onBack: _handleBack,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: switch (_step) {
                    0 => SelectLocationStep(onConfirmed: () => _goToStep(1)),
                    1 => MeetupDetailsStep(onConfirmed: () => _goToStep(2)),
                    _ => const InviteFriendsStep(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({required this.step, required this.title, required this.onBack});

  final int step;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: Text(title, style: AppTextStyles.displayLg)),
                  _StepProgress(step: step),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Create Meetup · Step ${step + 1} of 3',
                style: AppTextStyles.captionMd,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Slim 3-segment progress indicator: one pill per wizard step, filled for
/// the current step and everything before it.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            width: 18,
            height: 4,
            decoration: BoxDecoration(
              color: i <= step ? AppColors.accentDanger : AppColors.borderMuted,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
        ],
      ],
    );
  }
}
