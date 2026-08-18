import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/pill_button.dart';
import '../../meetups_controller.dart';

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Step 2 of the Create Meetup wizard: name the meetup and pick a date/time.
/// Date and time pickers are the stock Material dialogs (`showDatePicker` /
/// `showTimePicker`) - they inherit the app's dark theme automatically.
class MeetupDetailsStep extends StatefulWidget {
  const MeetupDetailsStep({super.key, required this.onConfirmed});

  /// Called after title/startTime have been written to the draft, so the
  /// wizard shell can advance to step 3.
  final VoidCallback onConfirmed;

  @override
  State<MeetupDetailsStep> createState() => _MeetupDetailsStepState();
}

class _MeetupDetailsStepState extends State<MeetupDetailsStep> {
  late final TextEditingController _titleController;
  DateTime? _date;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    final draft = context.read<MeetupsController>();
    _titleController = TextEditingController(text: draft.draftTitle);
    final startTime = draft.draftStartTime;
    if (startTime != null) {
      _date = DateTime(startTime.year, startTime.month, startTime.day);
      _time = TimeOfDay(hour: startTime.hour, minute: startTime.minute);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _titleController.text.trim().isNotEmpty && _date != null && _time != null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => _time = picked);
  }

  void _confirm() {
    final date = _date;
    final time = _time;
    if (date == null || time == null) return;
    context.read<MeetupsController>().setDraftDetails(
      title: _titleController.text.trim(),
      startTime: DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
    widget.onConfirmed();
  }

  String _formatDate(DateTime date) => '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

  @override
  Widget build(BuildContext context) {
    final location = context.watch<MeetupsController>().draftLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name', style: AppTextStyles.labelSm),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderSubtle, width: 0.6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: TextField(
                    controller: _titleController,
                    style: AppTextStyles.bodyMd,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Dinner meetup, splitting the bill for dessert',
                      hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Date', style: AppTextStyles.labelSm),
                const SizedBox(height: AppSpacing.sm),
                _PickerRow(
                  icon: Icons.calendar_today_outlined,
                  label: _date == null ? 'Select date' : _formatDate(_date!),
                  onTap: _pickDate,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Time', style: AppTextStyles.labelSm),
                const SizedBox(height: AppSpacing.sm),
                _PickerRow(
                  icon: Icons.access_time,
                  label: _time == null ? 'Select time' : _time!.format(context),
                  onTap: _pickTime,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (location != null)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(location.name, style: AppTextStyles.titleMd),
                        const SizedBox(height: 2),
                        Text(location.address, style: AppTextStyles.captionMd),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PillButton(
          label: 'Confirm Details',
          onPressed: _canConfirm ? _confirm : null,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTextStyles.bodyMd),
        ],
      ),
    );
  }
}
