import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/platform/system_channel.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/adherence/application/dose_actions.dart';
import 'package:reindeer/features/adherence/application/timeline_providers.dart';
import 'package:reindeer/features/adherence/domain/dose_timeline.dart';
import 'package:reindeer/features/adherence/domain/models/dose_log.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/features/tb/application/tb_actions.dart';
import 'package:reindeer/features/tb/data/tb_repository.dart';
import 'package:reindeer/features/tb/domain/tb_programme.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';

/// Asks the supporter for their PIN. True when it matches.
Future<bool> askSupporterPin(BuildContext context, TbProgramme p) async {
  final ctrl = TextEditingController();
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(trf('{n}, please confirm', {'n': p.supporterName})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('Type your PIN to confirm you watched the dose being taken.'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: ctrl,
              autofocus: true,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('PIN'),
                errorText: error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (hashPin(ctrl.text) == p.pinHash) {
                Navigator.pop(ctx, true);
              } else {
                setState(() => error = tr('Wrong PIN'));
              }
            },
            child: Text(tr('Confirm')),
          ),
        ],
      ),
    ),
  );
  // Not disposed here: the dialog is still animating out and uses it.
  return ok == true;
}

String _patientName(WidgetRef ref) {
  final n = ref.watch(profileProvider).value?.name ?? '';
  return n == 'Me' ? '' : n;
}

/// TB care: six-month progress, doses watched by a supporter, missed-dose
/// alerts, check-up dates and a report for the health worker.
class TbScreen extends ConsumerWidget {
  const TbScreen({super.key});

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    TbProgramme p,
    DoseEntry e,
  ) async {
    final ok = await askSupporterPin(context, p);
    if (!ok) return;
    await ref
        .read(tbActionsProvider)
        .confirm(e.dose, alreadyTaken: e.status == DoseStatus.taken);
    if (context.mounted) {
      context.showSnackBar(trf('Confirmed by {n}', {'n': p.supporterName}));
    }
  }

  Future<void> _tell(TbProgramme p, String patient, bool missed, int day) {
    final text = inEnglish(
      () => supporterMessage(patient: patient, missed: missed, day: day),
    );
    return p.supporterPhone.isEmpty
        ? SystemChannel.shareText(text)
        : SystemChannel.sms(p.supporterPhone, text);
  }

  Future<void> _end(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('End TB programme?')),
        content: Text(
          tr(
            'This stops the TB reminders in Reindeer. Only end it if your doctor or TB centre says treatment is complete or changed. Your records stay.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Keep it')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('End programme')),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await ref.read(tbActionsProvider).end();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programme = ref.watch(tbProgrammeProvider).value;
    final loading = ref.watch(tbProgrammeProvider).isLoading;
    final patient = _patientName(ref);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('TB care')),
        actions: [
          if (programme != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'end') _end(context, ref);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'end', child: Text(tr('End programme'))),
              ],
            ),
        ],
      ),
      body: programme == null
          ? (loading ? const SizedBox.shrink() : const _Intro())
          : _Active(
              programme: programme,
              onConfirm: (e) => _confirm(context, ref, programme, e),
              onTell: (missed, day) => _tell(programme, patient, missed, day),
            ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        Text(tr('Finish every dose, all six months'), style: t.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tr(
            'TB medicines work only if none are missed. Reindeer helps you finish the course with DOTS: a person you trust watches you take each dose.',
          ),
          style: t.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final line in [
          (Icons.alarm, tr('Daily reminder on an empty stomach')),
          (
            Icons.verified_user_outlined,
            tr('Your supporter confirms each dose with a PIN'),
          ),
          (
            Icons.sms_outlined,
            tr('One tap to tell your supporter about a missed dose'),
          ),
          (
            Icons.event_available_outlined,
            tr('Check-up dates and a report for your health worker'),
          ),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(line.$1),
            title: Text(line.$2),
          ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.tbSetup),
          icon: const Icon(Icons.play_arrow),
          label: Text(tr('Start TB treatment')),
        ),
      ],
    );
  }
}

class _Active extends ConsumerWidget {
  const _Active({
    required this.programme,
    required this.onConfirm,
    required this.onTell,
  });

  final TbProgramme programme;
  final void Function(DoseEntry) onConfirm;
  final Future<void> Function(bool missed, int day) onTell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final day = programme.dayNumber(now);
    final phase = programme.phaseOn(now);
    final observed = ref.watch(tbObservationsProvider).value ?? const {};
    final todays = [
      for (final e
          in ref.watch(todayEntriesProvider).value ?? const <DoseEntry>[])
        if (e.plan.condition == tbCondition) e,
    ];
    final recent =
        ref.watch(recentEntriesProvider(200)).value ?? const <DoseEntry>[];
    final adherence = TbAdherence.from(recent, observed.keys.toSet(), now);
    final patient = _patientName(ref);
    final missedToday = todays.any((e) => e.status == DoseStatus.missed);

    final phaseText = switch (phase) {
      TbPhase.notStarted => trf('Starts on {n}', {
        'n': formatLongDate(programme.firstDay),
      }),
      TbPhase.intensive => tr('First 2 months (4 medicines)'),
      TbPhase.continuation => tr('Next 4 months (3 medicines)'),
      TbPhase.completed => tr(
        'Course finished. Ask your TB centre for the final check.',
      ),
    };

    String pct(double? f) =>
        f == null ? tr('no data yet') : '${(f * 100).round()}%';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Card(
          margin: EdgeInsets.zero,
          color: scheme.primaryContainer,
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phase == TbPhase.completed
                      ? tr('Treatment complete')
                      : trf('Day {a} of {b}', {
                          'a': '${day < 1 ? 0 : day}',
                          'b': '$tbTotalDays',
                        }),
                  style: t.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  phaseText,
                  style: t.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: AppSpacing.borderRadiusSm,
                  child: LinearProgressIndicator(
                    value: programme.progress(now),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  trf(
                    '{n} days to go. Never stop early, even if you feel well.',
                    {'n': '${programme.daysLeft(now)}'},
                  ),
                  style: t.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (adherence.missedDaysInARow >= 2) ...[
          const SizedBox(height: AppSpacing.sm),
          Card(
            margin: EdgeInsets.zero,
            color: scheme.errorContainer,
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: scheme.onErrorContainer,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          trf('{n} days missed in a row', {
                            'n': '${adherence.missedDaysInARow}',
                          }),
                          style: t.titleMedium?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    tr(
                      'Please visit or call your TB centre or health worker today. Do not double the next dose or restart on your own.',
                    ),
                    style: t.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      if (programme.supporterPhone.isNotEmpty)
                        FilledButton.icon(
                          onPressed: () =>
                              SystemChannel.dial(programme.supporterPhone),
                          icon: const Icon(Icons.call),
                          label: Text(
                            trf('Call {n}', {'n': programme.supporterName}),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => onTell(true, day),
                        icon: const Icon(Icons.sms_outlined),
                        label: Text(tr('Message supporter')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        SectionTitle(tr('Today\'s doses')),
        if (todays.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: AppSpacing.cardPadding,
              child: Text(tr('No TB dose is due today.'), style: t.bodyLarge),
            ),
          )
        else
          for (final e in todays) ...[
            _DoseTile(
              entry: e,
              observer: observed[e.dose.key],
              onTake: () => ref.read(doseActionsProvider).take(e.dose),
              onConfirm: () => onConfirm(e),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        if (todays.any((e) => e.status == DoseStatus.taken) && !missedToday)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => onTell(false, day),
              icon: const Icon(Icons.send_outlined),
              label: Text(tr('Tell supporter I took it')),
            ),
          ),
        if (missedToday)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => onTell(true, day),
              icon: const Icon(Icons.sms_outlined),
              label: Text(tr('Tell supporter I missed it')),
            ),
          ),
        SectionTitle(tr('How it is going')),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Stat(tr('Doses taken'), '${adherence.taken}'),
                _Stat(tr('Doses missed'), '${adherence.missed}'),
                _Stat(tr('Taken of those due'), pct(adherence.takenFraction)),
                _Stat(
                  tr('Taken doses watched by supporter'),
                  '${adherence.observed} (${pct(adherence.observedFraction)})',
                ),
              ],
            ),
          ),
        ),
        SectionTitle(tr('Your supporter')),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(programme.supporterName, style: t.titleMedium),
                subtitle: programme.supporterPhone.isEmpty
                    ? null
                    : Text(programme.supporterPhone),
                trailing: programme.supporterPhone.isEmpty
                    ? null
                    : IconButton(
                        tooltip: tr('Call'),
                        icon: const Icon(Icons.call),
                        onPressed: () =>
                            SystemChannel.dial(programme.supporterPhone),
                      ),
              ),
              if (programme.nikshayId.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(tr('Nikshay ID')),
                  subtitle: Text(programme.nikshayId),
                ),
              ],
            ],
          ),
        ),
        SectionTitle(tr('Check-ups to ask about')),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, f) in programme.followUps().indexed) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    dateOnly(f.date).isBefore(dateOnly(now))
                        ? Icons.check_circle_outline
                        : Icons.event_outlined,
                  ),
                  title: Text(tr(f.label)),
                  subtitle: Text(formatLongDate(f.date)),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Text(
                  tr(
                    'Dates are the usual ones. Your TB centre will tell you the exact days.',
                  ),
                  style: t.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: () => SystemChannel.shareText(
            inEnglish(
              () => buildDotsReport(
                patient: patient,
                programme: programme,
                adherence: adherence,
                today: now,
              ),
            ),
            title: tr('Share report'),
          ),
          icon: const Icon(Icons.share_outlined),
          label: Text(tr('Share report with health worker')),
        ),
        SectionTitle(tr('Good to know')),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    'Orange or red urine is normal with rifampicin. It is not blood.',
                  ),
                  style: t.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tr(
                    'Tell your doctor the same day if you have yellow eyes or skin, vomiting that does not stop, blurred vision, numb or tingling feet, or a rash. Do not stop the medicines on your own.',
                  ),
                  style: t.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tr(
                    'TB treatment is free at government centres. Ask your TB centre about nutrition support for TB patients (Ni-kshay Poshan Yojana).',
                  ),
                  style: t.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label, style: context.textTheme.bodyLarge)),
        Text(value, style: context.textTheme.titleMedium),
      ],
    ),
  );
}

class _DoseTile extends StatelessWidget {
  const _DoseTile({
    required this.entry,
    required this.observer,
    required this.onTake,
    required this.onConfirm,
  });

  final DoseEntry entry;
  final String? observer;
  final VoidCallback onTake;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final e = entry;
    final taken = e.status == DoseStatus.taken;
    final missed = e.status == DoseStatus.missed;
    final status = switch (e.status) {
      DoseStatus.taken => tr('Taken'),
      DoseStatus.skipped => tr('Skipped'),
      DoseStatus.missed => tr('Missed'),
      _ => tr('Due'),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.plan.name, style: t.titleMedium),
            Text(
              '${formatTime(e.dose.at)} · ${e.plan.doseUnit.describe(e.dose.amount)} · $status',
              style: t.bodyMedium?.copyWith(
                color: missed ? scheme.error : null,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (observer != null)
              Chip(
                avatar: const Icon(Icons.verified, size: 18),
                label: Text(trf('Watched by {n}', {'n': observer!})),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (!taken && e.status != DoseStatus.skipped)
                    OutlinedButton(
                      onPressed: onTake,
                      child: Text(tr('I took it')),
                    ),
                  if (e.status != DoseStatus.skipped)
                    FilledButton.icon(
                      onPressed: onConfirm,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: Text(tr('Supporter confirms')),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
