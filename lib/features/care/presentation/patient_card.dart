import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/platform/system_channel.dart';
import 'package:reindeer/core/theme/app_colors.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/adherence/application/timeline_providers.dart';
import 'package:reindeer/features/adherence/domain/models/miss_reason.dart';
import 'package:reindeer/features/care/application/care_providers.dart';
import 'package:reindeer/features/care/data/care_backend.dart';
import 'package:reindeer/features/care/domain/care_models.dart';

/// "5 min ago", "3 h ago", for when a phone was last active.
String agoLabel(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 2) return tr('just now');
  if (d.inMinutes < 60) return trf('{n} min ago', {'n': '${d.inMinutes}'});
  if (d.inHours < 24) return trf('{n} h ago', {'n': '${d.inHours}'});
  return trn(d.inDays, '{n} day ago', '{n} days ago');
}

/// One-line summary of a person's day, with how worrying it is.
({String text, Color color, IconData icon}) daySummary(
  BuildContext context,
  List<CareDose> doses,
  DateTime now,
) {
  final scheme = context.colorScheme;
  if (doses.isEmpty) {
    return (
      text: tr('No medicines today'),
      color: scheme.onSurfaceVariant,
      icon: Icons.event_available_outlined,
    );
  }
  final taken = doses.where((d) => d.taken).length;
  final late = doses.where((d) => d.isLate(now)).length;
  if (late > 0) {
    return (
      text: trn(
        late,
        '{n} medicine not taken yet',
        '{n} medicines not taken yet',
      ),
      color: scheme.error,
      icon: Icons.warning_amber_rounded,
    );
  }
  final due = doses.where((d) => !d.at.isAfter(now)).length;
  if (due > 0 && taken + doses.where((d) => d.skipped).length >= due) {
    return (
      text: trf('All on time · {a} of {b} taken today', {
        'a': '$taken',
        'b': '${doses.length}',
      }),
      color: AppColors.success,
      icon: Icons.check_circle,
    );
  }
  return (
    text: trf('{a} of {b} taken today', {
      'a': '$taken',
      'b': '${doses.length}',
    }),
    color: scheme.onSurfaceVariant,
    icon: Icons.schedule,
  );
}

/// What a caretaker sees about one person: today's doses, phone battery, and
/// quick actions.
class PatientCard extends ConsumerWidget {
  const PatientCard({super.key, required this.link});

  final CareLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final info =
        ref.watch(patientInfoProvider(link.patientUid)).value ??
        const PatientInfo();
    final dosesAsync = ref.watch(patientDosesTodayProvider(link.patientUid));
    final doses = dosesAsync.value ?? const <CareDose>[];
    final requests =
        ref.watch(patientRequestsProvider(link.patientUid)).value ??
        const <CareRequest>[];
    final openRequest = requests
        .where((r) => now.difference(r.createdAt) < const Duration(days: 3))
        .firstOrNull;
    final summary = daySummary(context, doses, now);
    final name = link.patientLabel;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: t.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: t.titleLarge),
                      Row(
                        children: [
                          Icon(summary.icon, size: 18, color: summary.color),
                          const SizedBox(width: AppSpacing.xxs),
                          Expanded(
                            child: Text(
                              summary.text,
                              style: t.bodyLarge?.copyWith(
                                color: summary.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _LinkMenu(link: link),
              ],
            ),
            if (openRequest != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Material(
                color: scheme.tertiaryContainer,
                borderRadius: AppSpacing.borderRadiusMd,
                child: ListTile(
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppSpacing.borderRadiusMd,
                  ),
                  leading: Icon(
                    Icons.shopping_bag_outlined,
                    color: scheme.onTertiaryContainer,
                  ),
                  title: Text(
                    trf('{n} asked for medicines', {'n': name}),
                    style: t.titleMedium?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  subtitle: Text(
                    openRequest.items.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: scheme.onTertiaryContainer,
                  ),
                  onTap: () => context.push(
                    '/care/request/${link.patientUid}/${openRequest.id}',
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            if (dosesAsync.isLoading && doses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
            for (final d in doses) _DoseLine(dose: d, now: now),
            if (info.lastSeen != null || info.battery != null) ...[
              const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  if (info.battery != null) ...[
                    Icon(
                      info.charging
                          ? Icons.battery_charging_full
                          : (info.batteryLow
                                ? Icons.battery_alert
                                : Icons.battery_std),
                      size: 20,
                      color: info.batteryLow
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                    Text(
                      ' ${info.battery}%',
                      style: t.bodyMedium?.copyWith(
                        color: info.batteryLow ? scheme.error : null,
                        fontWeight: info.batteryLow ? FontWeight.w700 : null,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  if (info.lastSeen != null)
                    Expanded(
                      child: Text(
                        trf('Phone active {t}', {
                          't': agoLabel(info.lastSeen!, now),
                        }),
                        style: t.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (info.phone.isNotEmpty) ...[
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => SystemChannel.dial(info.phone),
                      icon: const Icon(Icons.call),
                      label: Text(tr('Call')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(child: _LoveButton(link: link)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseLine extends StatelessWidget {
  const _DoseLine({required this.dose, required this.now});

  final CareDose dose;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final (IconData icon, Color color, String status) = dose.taken
        ? (
            Icons.check_circle,
            AppColors.success,
            trf('Taken {t}', {'t': dose.doneTime}),
          )
        : dose.skipped
        ? (
            Icons.remove_circle_outline,
            scheme.onSurfaceVariant,
            dose.reason.isEmpty || dose.reason == 'unknown'
                ? tr('Skipped')
                : trf('Skipped · {r}', {
                    'r': MissReasonType.fromName(dose.reason).label,
                  }),
          )
        : dose.isLate(now)
        ? (Icons.error, scheme.error, tr('Not taken yet'))
        : (Icons.radio_button_unchecked, scheme.outline, tr('Coming up'));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(width: 76, child: Text(dose.time, style: t.bodyLarge)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dose.name, style: t.titleMedium),
                Text(
                  status,
                  style: t.bodyMedium?.copyWith(
                    color: color == scheme.outline
                        ? scheme.onSurfaceVariant
                        : color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sends a heart to the patient's phone; rests for a minute after each tap.
class _LoveButton extends StatefulWidget {
  const _LoveButton({required this.link});

  final CareLink link;

  @override
  State<_LoveButton> createState() => _LoveButtonState();
}

class _LoveButtonState extends State<_LoveButton> {
  static final Map<String, DateTime> _sentAt = {};
  bool _busy = false;

  bool get _resting {
    final at = _sentAt[widget.link.patientUid];
    return at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 1);
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await CareBackend.sendToPatient(widget.link.patientUid, 'love');
      _sentAt[widget.link.patientUid] = DateTime.now();
      if (mounted) {
        context.showSnackBar(
          trf('Love sent to {n} ❤️', {'n': widget.link.patientLabel}),
        );
      }
    } catch (_) {
      if (mounted) {
        context.showSnackBar(
          tr('Could not send. Check the internet.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    onPressed: _busy || _resting ? null : _send,
    icon: Text(_resting ? '✓' : '❤️'),
    label: Text(_resting ? tr('Love sent') : tr('Send love')),
  );
}

/// Alert choices, renaming and disconnecting, tucked away in a menu.
class _LinkMenu extends ConsumerWidget {
  const _LinkMenu({required this.link});

  final CareLink link;

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: link.nickname);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('What do you call them?')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(tr('Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      await CareBackend.updateLink(link.id, {'nickname': name});
    }
  }

  Future<void> _unlink(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('Stop looking after {n}?', {'n': link.patientLabel})),
        content: Text(
          tr(
            'You will no longer get alerts. They can add you again with a new code.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Stop')),
          ),
        ],
      ),
    );
    if (ok == true) await CareBackend.unlink(link.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: tr('More'),
      onSelected: (v) {
        switch (v) {
          case 'taken':
            CareBackend.updateLink(link.id, {'notifyTaken': !link.notifyTaken});
          case 'skipped':
            CareBackend.updateLink(link.id, {
              'notifySkipped': !link.notifySkipped,
            });
          case 'rename':
            _rename(context);
          case 'unlink':
            _unlink(context);
        }
      },
      itemBuilder: (ctx) => [
        CheckedPopupMenuItem(
          value: 'taken',
          checked: link.notifyTaken,
          child: Text(tr('Tell me each time a dose is taken')),
        ),
        CheckedPopupMenuItem(
          value: 'skipped',
          checked: link.notifySkipped,
          child: Text(tr('Tell me when a dose is skipped')),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'rename', child: Text(tr('Change name'))),
        PopupMenuItem(
          value: 'unlink',
          child: Text(
            tr('Stop looking after'),
            style: TextStyle(color: context.colorScheme.error),
          ),
        ),
      ],
    );
  }
}
