import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/features/tb/application/tb_actions.dart';
import 'package:reindeer/features/tb/domain/tb_programme.dart';

/// Starts a TB treatment programme: start date, weight, and the supporter who
/// will watch the doses.
class TbSetupScreen extends ConsumerStatefulWidget {
  const TbSetupScreen({super.key});

  @override
  ConsumerState<TbSetupScreen> createState() => _TbSetupScreenState();
}

class _TbSetupScreenState extends ConsumerState<TbSetupScreen> {
  DateTime _start = dateOnly(DateTime.now());
  int _band = 1;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _nikshay = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pin.dispose();
    _nikshay.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && isValidPin(_pin.text);

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(today.year, today.month, today.day - 60),
      lastDate: DateTime(today.year, today.month, today.day + 30),
    );
    if (d != null) setState(() => _start = dateOnly(d));
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(tbActionsProvider)
          .start(
            programme: TbProgramme(
              start: _start,
              supporterName: _name.text.trim(),
              supporterPhone: _phone.text.trim(),
              nikshayId: _nikshay.text.trim(),
              pinHash: hashPin(_pin.text),
            ),
            tablets: weightBands[_band].tablets,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showSnackBar(
        trf('Could not save: {n}', {'n': '$e'}),
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    context.go(AppRoutes.tb);
    context.showSnackBar(tr('TB treatment started. Reminders are set.'));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Start TB treatment'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Text(
            tr(
              'Reindeer will set up the usual six months: four medicines for 2 months, then three medicines for 4 months, once a day on an empty stomach. Use the card from your TB centre if it says anything different, and change the medicines later if your doctor does.',
            ),
            style: t.bodyLarge,
          ),
          SectionTitle(tr('When did treatment start?')),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(formatLongDate(_start)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
          ),
          SectionTitle(tr('Your weight')),
          Text(
            tr(
              'This sets how many tablets are suggested each day. Check it against your doctor\'s card.',
            ),
            style: t.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final (i, b) in weightBands.indexed) ...[
            ChoiceTile(
              label: tr(b.label),
              caption: trf('{n} tablets a day', {'n': '${b.tablets}'}),
              selected: _band == i,
              onTap: () => setState(() => _band = i),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          SectionTitle(tr('Your treatment supporter')),
          Text(
            tr(
              'A family member, ASHA or health worker who watches you take each dose (DOTS). They type their PIN in your phone to confirm.',
            ),
            style: t.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: tr('Supporter\'s name'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: tr('Supporter\'s phone (optional)'),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: tr('Supporter\'s 4-digit PIN'),
              helperText: tr(
                'Choose it together. Only the supporter should know it.',
              ),
              prefixIcon: const Icon(Icons.pin_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _nikshay,
            decoration: InputDecoration(
              labelText: tr('Nikshay ID (optional)'),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _valid && !_saving ? _save : null,
            child: Text(tr('Start treatment')),
          ),
        ],
      ),
    );
  }
}
