import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pill_button.dart';
import '../data/saved_locations_repository.dart';
import '../models/saved_location.dart';

/// Lists the current user's saved locations (GET /v1/saved-locations), with
/// an "add" entry point at the top leading to [AddSavedLocationScreen]
/// (POST /v1/saved-locations).
class SavedLocationsScreen extends StatefulWidget {
  const SavedLocationsScreen({super.key});

  @override
  State<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  bool _loading = true;
  String? _error;
  List<SavedLocation> _locations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final locations = await context.read<SavedLocationsRepository>().list();
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดสถานที่บันทึกไว้ไม่สำเร็จ กรุณาลองใหม่';
        _loading = false;
      });
    }
  }

  Future<void> _goToAdd() async {
    await context.push('/saved-locations/add');
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                    child: Text('สถานที่บันทึกไว้', style: AppTextStyles.displayLg),
                  ),
                  IconButton(
                    onPressed: _goToAdd,
                    icon: const Icon(Icons.add, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            PillOutlineButton(label: 'ลองใหม่', onPressed: _load),
          ],
        ),
      );
    }

    if (_locations.isEmpty) {
      return Center(
        child: Text(
          'ยังไม่มีสถานที่บันทึกไว้ กดปุ่ม + เพื่อเพิ่มสถานที่แรกของคุณ',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      itemCount: _locations.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final location = _locations[index];
        return AppCard(
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.textBody),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(location.name, style: AppTextStyles.titleMd)),
            ],
          ),
        );
      },
    );
  }
}
