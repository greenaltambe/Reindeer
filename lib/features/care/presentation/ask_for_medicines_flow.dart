import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/care/application/care_providers.dart';
import 'package:reindeer/features/care/data/care_backend.dart';
import 'package:reindeer/features/care/domain/care_models.dart';
import 'package:reindeer/features/medications/data/plan_repository.dart';
import 'package:reindeer/features/medications/domain/models/medication_plan.dart';
import 'package:reindeer/shared/widgets/choice_tile.dart';
import 'package:reindeer/shared/widgets/fade_slide_in.dart';
import 'package:reindeer/shared/widgets/step_scaffold.dart';

/// Biggest photo that fits in one Firestore document once base64-encoded.
const int _maxPhotoBytes = 540 * 1024;

/// "Ask my caretaker to buy medicines": pick medicines, optionally add the
/// prescription photo, send.
class AskForMedicinesFlow extends ConsumerStatefulWidget {
  const AskForMedicinesFlow({super.key});

  @override
  ConsumerState<AskForMedicinesFlow> createState() =>
      _AskForMedicinesFlowState();
}

class _AskForMedicinesFlowState extends ConsumerState<AskForMedicinesFlow> {
  static const _steps = 3;

  int _step = 0;
  Set<int>? _picked;
  Uint8List? _photo;
  bool _busy = false;
  bool _sent = false;

  void _next() => setState(() => _step++);
  void _back() => setState(() => _step--);

  Future<void> _takePhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 60,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxPhotoBytes) {
        if (mounted) {
          context.showSnackBar(
            tr('That photo is too large. Please try again.'),
            isError: true,
          );
        }
        return;
      }
      setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) {
        context.showSnackBar(tr('Could not open the camera.'), isError: true);
      }
    }
  }

  Future<void> _send(List<MedicationPlan> plans) async {
    setState(() => _busy = true);
    try {
      final photo = _photo;
      await CareBackend.sendPatientEvent(
        'request',
        items: [
          for (final p in plans)
            if (_picked!.contains(p.id)) p.name,
        ],
        photoBase64: photo == null ? null : base64Encode(photo),
      );
      if (mounted) setState(() => _sent = true);
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
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final caretakers =
        ref.watch(myCaretakersProvider).value ?? const <CareLink>[];
    final who = caretakers.isEmpty
        ? tr('your caretaker')
        : caretakers.map((c) => c.caretakerLabel).join(', ');
    final plans = (ref.watch(plansProvider).value ?? const <MedicationPlan>[])
        .where((p) => p.isActive && p.id != null)
        .toList();
    // Medicines running low are ticked to start with.
    final picked = _picked ??= {
      for (final p in plans)
        if (p.isLowStock) p.id!,
    };

    if (_sent) {
      return Scaffold(
        body: StepScaffold(
          stepIndex: _steps - 1,
          stepCount: _steps,
          leading: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Icon(Icons.check_circle, size: 72, color: scheme.primary),
          ),
          title: tr('Sent!'),
          subtitle: trf('{n} will get a notification on their phone.', {
            'n': who,
          }),
          nextLabel: tr('Done'),
          onNext: () => context.pop(),
          child: const SizedBox.shrink(),
        ),
      );
    }

    final page = switch (_step) {
      0 => StepScaffold(
        stepIndex: 0,
        stepCount: _steps,
        title: tr('Which medicines do you need?'),
        subtitle: tr('Tap to choose. Ones running low are already ticked.'),
        onBack: () => context.pop(),
        nextEnabled: picked.isNotEmpty,
        onNext: _next,
        child: Column(
          children: [
            for (final p in plans)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: ChoiceTile(
                  label: p.name,
                  caption: p.isLowStock ? tr('Running low') : null,
                  icon: picked.contains(p.id)
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  selected: picked.contains(p.id),
                  onTap: () => setState(() {
                    if (!picked.remove(p.id)) picked.add(p.id!);
                  }),
                ),
              ),
          ],
        ),
      ),
      1 => StepScaffold(
        stepIndex: 1,
        stepCount: _steps,
        title: tr('Add the prescription?'),
        subtitle: tr('A photo helps them buy the right medicine. Optional.'),
        onBack: _back,
        nextLabel: _photo == null ? tr('Skip') : tr('Next'),
        onNext: _next,
        child: _photo == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                      textStyle: t.titleMedium,
                    ),
                    onPressed: () => _takePhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined, size: 28),
                    label: Text(tr('Take a photo')),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                      textStyle: t.titleMedium,
                    ),
                    onPressed: () => _takePhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 28),
                    label: Text(tr('Choose from gallery')),
                  ),
                ],
              )
            : FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: AppSpacing.borderRadiusMd,
                      child: Image.memory(
                        _photo!,
                        height: 280,
                        fit: BoxFit.cover,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _photo = null),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(tr('Remove photo')),
                    ),
                  ],
                ),
              ),
      ),
      _ => StepScaffold(
        stepIndex: 2,
        stepCount: _steps,
        title: trf('Send to {n}?', {'n': who}),
        onBack: _busy ? null : _back,
        busy: _busy,
        nextLabel: tr('Send'),
        onNext: () => _send(plans),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in plans)
                  if (picked.contains(p.id))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          const Icon(Icons.medication_outlined),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(child: Text(p.name, style: t.titleMedium)),
                        ],
                      ),
                    ),
                if (_photo != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.image_outlined),
                      const SizedBox(width: AppSpacing.xs),
                      Text(tr('Prescription photo'), style: t.titleMedium),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _back();
      },
      child: Scaffold(
        body: StepSwitcher(index: _step, child: page),
      ),
    );
  }
}

/// Card on Refills: one tap to ask the caretaker to buy medicines. Hidden
/// for people without a caretaker.
class AskCaretakerCard extends ConsumerWidget {
  const AskCaretakerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caretakers =
        ref.watch(myCaretakersProvider).value ?? const <CareLink>[];
    if (caretakers.isEmpty) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    final who = caretakers.first.caretakerLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        margin: EdgeInsets.zero,
        color: scheme.secondaryContainer,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          leading: Icon(
            Icons.shopping_bag_outlined,
            color: scheme.onSecondaryContainer,
            size: 30,
          ),
          title: Text(
            trf('Ask {n} to buy medicines', {'n': who}),
            style: context.textTheme.titleMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
          subtitle: Text(
            tr('Send the list and a prescription photo'),
            style: TextStyle(color: scheme.onSecondaryContainer),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: scheme.onSecondaryContainer,
          ),
          onTap: () => context.push(AppRoutes.familyAsk),
        ),
      ),
    );
  }
}
