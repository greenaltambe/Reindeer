import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/database/app_database.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/conditions/presentation/condition_picker.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/shared/widgets/year_wheel_picker.dart';

/// Edit the name, birth year, height and health conditions.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _year = TextEditingController();
  final _height = TextEditingController();
  List<String> _conditions = [];
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    _height.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(profileRepositoryProvider);
    final p = await repo.get();
    final c = await repo.conditions();
    if (!mounted) return;
    setState(() {
      _name.text = p.name;
      _year.text = p.birthYear?.toString() ?? '';
      _height.text = p.heightCm == null ? '' : p.heightCm!.round().toString();
      _conditions = c;
      _loaded = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final y = int.tryParse(_year.text.trim());
      final h = double.tryParse(_height.text.trim());
      final repo = ref.read(profileRepositoryProvider);
      await repo.save(
        name: _name.text,
        birthYear: (y != null && y >= 1900 && y <= DateTime.now().year)
            ? y
            : null,
        heightCm: (h != null && h >= 50 && h <= 260) ? h : null,
      );
      await repo.setConditions(_conditions);
      ref.read(dataVersionProvider.notifier).bump();
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showSnackBar(trf('Could not save: {n}', {'n': '$e'}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Your profile'))),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: tr('Name')),
                ),
                const SizedBox(height: AppSpacing.sm),
                InkWell(
                  onTap: () async {
                    final current = int.tryParse(_year.text.trim());
                    final picked = await showYearWheelPickerSheet(
                      context: context,
                      initialYear: current ?? (DateTime.now().year - 45),
                    );
                    if (picked != null) {
                      setState(() => _year.text = '$picked');
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: IgnorePointer(
                    child: TextField(
                      controller: _year,
                      decoration: InputDecoration(
                        labelText: tr('Birth year'),
                        suffixIcon: const Icon(Icons.calendar_today_rounded),
                        hintText: tr('Tap to select birth year'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _height,
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  decoration: InputDecoration(
                    labelText: tr('Height'),
                    suffixText: 'cm',
                    helperText: tr(
                      'Used only to work out BMI from your weight.',
                    ),
                    counterText: '',
                  ),
                ),
                SectionTitle(tr('Health conditions')),
                ConditionPicker(
                  selected: _conditions,
                  onChanged: (v) => setState(() => _conditions = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(tr('Save')),
                ),
              ],
            ),
    );
  }
}
