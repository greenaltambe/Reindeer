import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_constants.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/platform/system_channel.dart';
import 'package:reindeer/core/theme/theme_provider.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/backup/data/backup_service.dart';
import 'package:reindeer/features/backup/domain/backup_codec.dart';
import 'package:reindeer/features/reminders/reminder_service.dart';
import 'package:reindeer/features/settings/data/settings_repository.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/shared/widgets/reindeer_mark.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/shared/widgets/language_picker.dart';

/// App settings: reminder health check, appearance and about. Personal
/// details and meal times live on the You tab.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final health = ref.watch(reminderHealthProvider).value;
    final status = ref.watch(reminderStatusProvider).value;
    final t = context.textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Settings'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          SectionTitle(tr('Reminders')),
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HealthRow(
                    ok: health?.notificationsEnabled,
                    label: tr('Notifications allowed'),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _HealthRow(
                    ok: health?.exactAlarms,
                    label: tr('Exact-time reminders allowed'),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  _HealthRow(
                    ok: health?.batteryUnrestricted,
                    label: tr('Battery: not restricted'),
                  ),
                  const _LoudSwitch(),
                  if (status != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      status.report.failed > 0
                          ? '${status.pending} reminders waiting. ${status.report.failed} could not be set: ${status.report.lastError ?? 'unknown error'}'
                          : trf('{n} reminders waiting for the next 7 days.', {
                              'n': '${status.pending}',
                            }),
                      style: t.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (health != null && !health.allGood)
                        FilledButton(
                          onPressed: () async {
                            await ref
                                .read(reminderServiceProvider)
                                .requestPermissions();
                            ref.invalidate(reminderHealthProvider);
                          },
                          child: Text(tr('Fix permissions')),
                        ),
                      if (health != null && health.batteryUnrestricted == false)
                        FilledButton.tonal(
                          onPressed: () async {
                            await SystemChannel.requestIgnoreBatteryOptimizations();
                            ref.invalidate(reminderHealthProvider);
                          },
                          child: Text(tr('Allow background running')),
                        ),
                      OutlinedButton(
                        onPressed: () =>
                            ref.read(reminderServiceProvider).showTest(),
                        child: Text(tr('Test now')),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final how = await ref
                              .read(reminderServiceProvider)
                              .scheduleTest(const Duration(minutes: 1));
                          ref.invalidate(reminderStatusProvider);
                          if (context.mounted) {
                            context.showSnackBar(
                              'Test set ($how). Close the app and wait one minute.',
                            );
                          }
                        },
                        child: Text(tr('Test in 1 minute')),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await ref
                              .read(reminderServiceProvider)
                              .rescheduleAll();
                          ref.read(dataVersionProvider.notifier).bump();
                          ref.invalidate(reminderStatusProvider);
                          if (context.mounted) {
                            context.showSnackBar(tr('Reminders rebuilt'));
                          }
                        },
                        child: Text(tr('Rebuild reminders')),
                      ),
                      TextButton(
                        onPressed: SystemChannel.openAppSettings,
                        child: Text(tr('Phone app settings')),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    tr(
                      'If reminders arrive late or not at all, set Reindeer to "Unrestricted" under Battery. On Oppo, Realme, OnePlus, Xiaomi, Vivo and Samsung phones also allow "Auto-start" and lock Reindeer in the recent apps list, otherwise the phone may stop it and cancel reminders.',
                    ),
                    style: t.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          SectionTitle(tr('Language')),
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      'Choose the language for the app. Reminders use it too.',
                    ),
                    style: t.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const LanguagePicker(),
                ],
              ),
            ),
          ),
          SectionTitle(tr('Backup')),
          const _BackupCard(),
          SectionTitle(tr('Appearance')),
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text(tr('Auto')),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text(tr('Light')),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text(tr('Dark')),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (s) => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(s.first),
                ),
              ),
            ),
          ),
          SectionTitle(tr('About')),
          Card(
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ReindeerMark(size: 48, interactive: true),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${AppConstants.appName} ${AppConstants.appVersion}',
                          style: t.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    tr(
                      'Reindeer is a reminder tool. It does not give medical advice and does not check doses or interactions. Always follow your doctor\'s prescription.\n\nMedicine details come from public lists (a community medicine dataset and the Jan Aushadhi product list) and may be incomplete or out of date.\n\nAll your data stays on this phone. There is no account and nothing is uploaded.',
                    ),
                    style: t.bodyMedium,
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

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.ok, required this.label});

  final bool? ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final (IconData icon, Color color) = switch (ok) {
      true => (Icons.check_circle, scheme.primary),
      false => (Icons.error_outline, scheme.error),
      null => (Icons.hourglass_empty, scheme.outline),
    };
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: context.textTheme.bodyLarge),
      ],
    );
  }
}

/// Save everything to a file and bring it back, for a new phone or a reset.
class _BackupCard extends ConsumerStatefulWidget {
  const _BackupCard();

  @override
  ConsumerState<_BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends ConsumerState<_BackupCard> {
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final text = await ref.read(backupServiceProvider).export();
      final d = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final name =
          'reindeer-backup-${d.year}-${two(d.month)}-${two(d.day)}.json';
      final ok = await SystemChannel.saveTextFile(name, text);
      if (!mounted) return;
      if (ok) {
        context.showSnackBar(tr('Backup saved'));
      }
    } catch (_) {
      if (mounted) {
        context.showSnackBar(tr('Could not save the backup'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final text = await SystemChannel.pickTextFile();
      if (text == null || !mounted) {
        return;
      }
      final BackupData data;
      try {
        data = decodeBackup(text);
      } on FormatException catch (e) {
        if (mounted) context.showSnackBar(e.message, isError: true);
        return;
      }
      final s = summarize(data);
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Restore this backup?')),
          content: Text(
            trf(
              'It has {a} medicines, {b} dose records and {c} readings.\n\nEverything now in Reindeer will be replaced.',
              {'a': '${s.medicines}', 'b': '${s.doses}', 'c': '${s.readings}'},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Restore')),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
      await ref.read(backupServiceProvider).restore(data);
      if (mounted) context.showSnackBar(tr('Backup restored'));
    } catch (_) {
      if (mounted) {
        context.showSnackBar(
          tr('Could not restore. Nothing was changed.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                'Save your medicines, doses, readings and notes to a file. Keep it in Google Drive or send it to yourself, then restore it on a new phone.',
              ),
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save_alt),
                  label: Text(tr('Save backup')),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _restore,
                  icon: const Icon(Icons.restore),
                  label: Text(tr('Restore')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Loud, repeating reminders that ring until the person responds.
class _LoudSwitch extends ConsumerWidget {
  const _LoudSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(loudRemindersProvider).value ?? false;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(tr('Loud repeating reminders')),
      subtitle: Text(
        tr(
          'Rings at alarm volume and repeats until you tap Taken, Skip or Snooze. Good if you often miss a normal notification.',
        ),
      ),
      value: on,
      onChanged: (v) async {
        await ref
            .read(settingsRepositoryProvider)
            .set(keyPersistentAlarm, v ? '1' : '0');
        ref.invalidate(loudRemindersProvider);
        await ref.read(reminderServiceProvider).rescheduleAll();
      },
    );
  }
}

final loudRemindersProvider = FutureProvider<bool>((ref) async {
  return (await ref.read(settingsRepositoryProvider).get(keyPersistentAlarm)) ==
      '1';
});
