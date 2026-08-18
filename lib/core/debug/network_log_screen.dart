import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/status_badge.dart';
import 'network_log_entry.dart';
import 'network_log_store.dart';

const _monospace = TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4);

/// In-app network inspector: browse every API call this session, most recent
/// first, and drill into any one for its full request/response detail.
/// Reachable via the floating [NetworkDebugButton] overlaid in debug builds.
class NetworkLogScreen extends StatelessWidget {
  const NetworkLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: NetworkLogStore.instance.clear,
            tooltip: 'Clear',
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: NetworkLogStore.instance,
          builder: (context, _) {
            final entries = NetworkLogStore.instance.entries;
            if (entries.isEmpty) {
              return Center(
                child: Text('No API calls yet', style: AppTextStyles.captionMd),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _EntryRow(entry: entries[index]),
            );
          },
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final NetworkLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusBadge(entry);
    final path = Uri.tryParse(entry.url)?.path ?? entry.url;

    return AppCard(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => NetworkLogDetailScreen(entry: entry)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.method,
                style: AppTextStyles.captionMd.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  path,
                  style: AppTextStyles.bodyMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(label: label, color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(_subtitle(entry), style: AppTextStyles.captionMd),
        ],
      ),
    );
  }
}

/// Full request/response for one recorded call, with pretty-printed JSON
/// bodies where possible.
class NetworkLogDetailScreen extends StatelessWidget {
  const NetworkLogDetailScreen({super.key, required this.entry});

  final NetworkLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statusBadge(entry);

    return Scaffold(
      appBar: AppBar(title: Text('${entry.method} ${entry.url}', maxLines: 1)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                StatusBadge(label: label, color: color),
                const SizedBox(width: AppSpacing.sm),
                Text(_subtitle(entry), style: AppTextStyles.captionMd),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(title: 'Request Headers', body: _prettyPrint(entry.requestHeaders)),
            if (entry.requestBody != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _Section(title: 'Request Body', body: _prettyPrint(entry.requestBody)),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (entry.errorMessage != null)
              _Section(title: 'Error', body: entry.errorMessage!, danger: true)
            else if (!entry.isPending)
              _Section(title: 'Response Body', body: _prettyPrint(entry.responseBody)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body, this.danger = false});

  final String title;
  final String body;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppTextStyles.labelSm),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: SelectableText(
            body,
            style: _monospace.copyWith(color: danger ? AppColors.accentDanger : null),
          ),
        ),
      ],
    );
  }
}

(String, Color) _statusBadge(NetworkLogEntry entry) {
  if (entry.isPending) return ('...', BadgeColors.neutral);
  if (entry.errorMessage != null && entry.statusCode == null) {
    return ('ERR', BadgeColors.negative);
  }
  final code = entry.statusCode!;
  return ('$code', code >= 400 ? BadgeColors.negative : BadgeColors.positive);
}

String _subtitle(NetworkLogEntry entry) {
  final time = entry.startedAt;
  final timeLabel =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  final durationLabel = entry.duration == null
      ? 'pending'
      : '${entry.duration!.inMilliseconds} ms';
  return '$timeLabel · $durationLabel';
}

String _prettyPrint(Object? value) {
  if (value == null) return '(empty)';
  if (value is String) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(value));
    } catch (_) {
      return value;
    }
  }
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}
