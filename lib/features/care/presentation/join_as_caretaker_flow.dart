import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/care/application/care_messaging.dart';
import 'package:reindeer/features/care/application/care_providers.dart';
import 'package:reindeer/features/care/data/care_backend.dart';
import 'package:reindeer/features/care/domain/care_models.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/shared/widgets/fade_slide_in.dart';
import 'package:reindeer/shared/widgets/step_scaffold.dart';

/// Caretaker side of linking, one question per page: your name, the code from
/// their phone, what you call them, your number, then alerts.
class JoinAsCaretakerFlow extends ConsumerStatefulWidget {
  const JoinAsCaretakerFlow({super.key});

  @override
  ConsumerState<JoinAsCaretakerFlow> createState() =>
      _JoinAsCaretakerFlowState();
}

class _JoinAsCaretakerFlowState extends ConsumerState<JoinAsCaretakerFlow> {
  static const _steps = 5;

  int _step = 0;
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _nickname = TextEditingController();
  final _phone = TextEditingController();
  String? _error;
  bool _busy = false;
  String? _linkId;

  @override
  void initState() {
    super.initState();
    ref.read(profileProvider.future).then((p) {
      // 'Me' is the placeholder for a skipped name.
      if (mounted && _name.text.isEmpty && p.name != 'Me') _name.text = p.name;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _nickname.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step++);
  void _back() => setState(() {
    _error = null;
    _step--;
  });

  String get _who =>
      _nickname.text.trim().isEmpty ? tr('them') : _nickname.text.trim();

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = _name.text.trim();
      final claim = await CareBackend.claimInvite(_code.text, name: name);
      await ref.read(careUidProvider.notifier).signIn();
      _linkId = claim.linkId;
      _nickname.text = claim.patientName;
      final profiles = ref.read(profileRepositoryProvider);
      final p = await profiles.get();
      if ((p.name.trim().isEmpty || p.name == 'Me') && name.isNotEmpty) {
        await profiles.save(
          name: name,
          birthYear: p.birthYear,
          heightCm: p.heightCm,
        );
      }
      if (mounted) _next();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(Map<String, Object?> data) async {
    final id = _linkId;
    if (id == null) return;
    try {
      await CareBackend.updateLink(id, data);
    } catch (_) {
      // Saved offline and sent later by Firestore.
    }
  }

  Future<void> _finish({required bool allow}) async {
    setState(() => _busy = true);
    if (allow) await CareMessaging.requestPermission();
    await CareBackend.registerDevice();
    if (!mounted) return;
    final mode = await ref.read(careModeProvider.future);
    if (!mounted) return;
    if (mode == CareMode.caretaker || !context.canPop()) {
      context.go(AppRoutes.care);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final page = switch (_step) {
      0 => StepScaffold(
        stepIndex: 0,
        stepCount: _steps,
        leading: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Icon(
            Icons.volunteer_activism,
            size: 64,
            color: scheme.primary,
          ),
        ),
        title: tr('What is your name?'),
        subtitle: tr('They will see this name on their phone.'),
        onBack: context.canPop() ? () => context.pop() : null,
        nextEnabled: _name.text.trim().isNotEmpty,
        onNext: _next,
        child: TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: t.titleLarge,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: tr('Your name')),
        ),
      ),
      1 => StepScaffold(
        stepIndex: 1,
        stepCount: _steps,
        title: tr('Enter the code from their phone'),
        subtitle: tr(
          'On their phone: open Reindeer, go to You > Family, and tap "Add a caretaker".',
        ),
        onBack: _busy ? null : _back,
        nextLabel: tr('Connect'),
        busy: _busy,
        nextEnabled: _code.text.length == 6,
        onNext: _connect,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: t.displaySmall?.copyWith(
                letterSpacing: 10,
                fontWeight: FontWeight.w700,
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) {
                if (_code.text.length == 6 && !_busy) _connect();
              },
              decoration: const InputDecoration(
                hintText: '------',
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: t.bodyLarge?.copyWith(color: scheme.error)),
            ],
          ],
        ),
      ),
      2 => StepScaffold(
        stepIndex: 2,
        stepCount: _steps,
        leading: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Icon(Icons.check_circle, size: 64, color: scheme.primary),
        ),
        title: tr('Connected! What do you call them?'),
        subtitle: tr('Alerts will use this name.'),
        nextEnabled: _nickname.text.trim().isNotEmpty,
        onNext: () {
          _save({'nickname': _nickname.text.trim()});
          _next();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nickname,
              textCapitalization: TextCapitalization.words,
              style: t.titleLarge,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final n in [
                  tr('Mom'),
                  tr('Dad'),
                  tr('Grandma'),
                  tr('Grandpa'),
                ])
                  ActionChip(
                    label: Text(n, style: t.titleMedium),
                    onPressed: () => setState(() => _nickname.text = n),
                  ),
              ],
            ),
          ],
        ),
      ),
      3 => StepScaffold(
        stepIndex: 3,
        stepCount: _steps,
        title: tr('Your phone number'),
        subtitle: trf(
          '{n} can call or WhatsApp you with one tap from the Help button.',
          {'n': _who},
        ),
        onBack: _back,
        onNext: () {
          _save({'caretakerPhone': _phone.text.trim()});
          _next();
        },
        onSkip: _next,
        child: TextField(
          controller: _phone,
          autofocus: true,
          keyboardType: TextInputType.phone,
          style: t.titleLarge,
          decoration: InputDecoration(hintText: tr('Mobile number')),
        ),
      ),
      _ => StepScaffold(
        stepIndex: 4,
        stepCount: _steps,
        leading: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Icon(
            Icons.notifications_active_outlined,
            size: 56,
            color: scheme.primary,
          ),
        ),
        title: tr('Allow alerts'),
        subtitle: trf(
          'So you hear right away if {n} misses a medicine or needs help.',
          {'n': _who},
        ),
        onBack: _busy ? null : _back,
        busy: _busy,
        nextLabel: tr('Allow alerts'),
        onNext: () => _finish(allow: true),
        onSkip: () => _finish(allow: false),
        child: const SizedBox.shrink(),
      ),
    };
    return PopScope(
      canPop: _step == 0 || _step == 2,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _back();
      },
      child: Scaffold(
        body: StepSwitcher(index: _step, child: page),
      ),
    );
  }
}
