import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../meetups_controller.dart';
import '../models/meetup_enums.dart';

/// Full-screen "your friend heading home wants to know you're okay" prompt.
///
/// Pushed imperatively onto the app's root [Navigator] by
/// `NudgeMessagingCoordinator` (foreground FCM message, background-tap, or
/// cold-start check), same as [NudgeAlertScreen] - see that screen's doc
/// comment for why. Unlike the nudge alert, answering here actually posts
/// back to the server (`MeetupsController.respondCheckIn`) so the asker sees
/// the answer on their next poll.
class CheckInAlertScreen extends StatefulWidget {
  const CheckInAlertScreen({
    super.key,
    required this.meetupId,
    required this.fromDisplayName,
  });

  final String meetupId;

  /// Display name of the member who asked, when known (FCM data payload).
  /// Falls back to a generic Thai placeholder otherwise.
  final String fromDisplayName;

  @override
  State<CheckInAlertScreen> createState() => _CheckInAlertScreenState();
}

class _CheckInAlertScreenState extends State<CheckInAlertScreen> {
  bool _submitting = false;

  Future<void> _respond(CheckInStatus status) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await context.read<MeetupsController>().respondCheckIn(widget.meetupId, status);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/mascots/waiting.png',
                  width: 160,
                  height: 160,
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'โอเคนะคะ?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.displayLg.copyWith(fontSize: 32, height: 1.3),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${widget.fromDisplayName} อยากรู้ว่าคุณกลับบ้านปลอดภัยไหม',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMd,
                ),
                const SizedBox(height: AppSpacing.xxl * 2),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => _respond(CheckInStatus.notOk),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('ไม่โอเค'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : () => _respond(CheckInStatus.ok),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.bgSurface,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          shape: const StadiumBorder(),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('โอเค'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
