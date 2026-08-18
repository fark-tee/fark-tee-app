import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'network_log_screen.dart';
import 'network_log_store.dart';

/// Small draggable "bug" button overlaid above the whole app (debug builds
/// only, see `app.dart`) that opens [NetworkLogScreen]. Its badge shows how
/// many calls have been recorded this session.
class NetworkDebugButton extends StatefulWidget {
  const NetworkDebugButton({super.key});

  @override
  State<NetworkDebugButton> createState() => _NetworkDebugButtonState();
}

class _NetworkDebugButtonState extends State<NetworkDebugButton> {
  Offset _offset = const Offset(16, 100);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Positioned(
      left: _offset.dx.clamp(0, size.width - 48),
      top: _offset.dy.clamp(0, size.height - 48),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() => _offset += details.delta);
        },
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const NetworkLogScreen()),
        ),
        child: ListenableBuilder(
          listenable: NetworkLogStore.instance,
          builder: (context, _) {
            final count = NetworkLogStore.instance.entries.length;
            return Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderMuted),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 8),
                ],
              ),
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.bug_report, color: AppColors.textPrimary),
                  if (count > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accentDanger,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
