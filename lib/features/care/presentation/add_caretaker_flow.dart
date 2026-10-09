import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/platform/system_channel.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/care/application/care_providers.dart';
import 'package:reindeer/features/care/data/care_backend.dart';
import 'package:reindeer/features/care/domain/care_models.dart';
import 'package:reindeer/features/profile/data/profile_repository.dart';
import 'package:reindeer/shared/widgets/fade_slide_in.dart';
import 'package:reindeer/shared/widgets/step_scaffold.dart';

/// Patient side of linking, one question per page: what sharing means, your
/// name, your phone number, then a code for the caretaker to type in.
class AddCaretakerFlow extends ConsumerStatefulWidget {
  const AddCaretakerFlow({super.key});

  @override
  ConsumerState<AddCaretakerFlow> createState() => _AddCaretakerFlowState();
}

class _AddCaretakerFlowState extends ConsumerState<AddCaretakerFlow> {
  static const _steps = 4;

  int _step = 0;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _code;
  String? _error;
  bool _busy = false;

  /// Caretakers there before this code was made, so a new one stands out.
  Set<String>? _before;

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
    final code = _code;
    if (code != null) CareBackend.cancelInvite(code);
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step++);
  void _back() => setState(() => _step--);

  Future<void> _makeCode() async {
    setState(() {
      _busy = true;
      _error = null;
      _step = 3;
    });
    try {
      await ref.read(careUidProvider.notifier).signIn();
      final name = _name.text.trim();
      if (name.isNotEmpty) {
        final profiles = ref.read(profileRepositoryProvider);
        final p = await profiles.get();
        if (p.name.trim().isEmpty || p.name == 'Me') {
          await profiles.save(
            name: name,
            birthYear: p.birthYear,
            heightCm: p.heightCm,
          );
        }
      }
      final existing = await ref
          .read(myCaretakersProvider.future)
          .timeout(const Duration(seconds: 10), onTimeout: () => const []);
      _before = {for (final l in existing) l.id};
      final code = await CareBackend.createInvite(patientName: name);
      await CareBackend.savePatientInfo(phone: _phone.text.trim());
      if (!mounted) {
        CareBackend.cancelInvite(code);
        return;
      }
      setState(() => _code = code);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
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
          child: Icon(Icons.family_restroom, size: 64, color: scheme.primary),
        ),
        title: tr('Let family keep watch'),
        subtitle: tr(
          'If you miss a medicine, Reindeer quietly tells someone you trust.',
        ),
        onBack: () => context.pop(),
        nextLabel: tr('Continue'),
        onNext: _next,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Benefit(
              icon: Icons.notifications_active_outlined,
              text: tr('They get an alert if a dose is missed'),
            ),
            _Benefit(
              icon: Icons.sos_outlined,
              text: tr('You get a Help button to reach them fast'),
            ),
            _Benefit(
              icon: Icons.shopping_bag_outlined,
              text: tr('You can ask them to buy medicines'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr(
                'They see your medicine names, times and whether you took them. Nothing else leaves this phone.',
              ),
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      1 => StepScaffold(
        stepIndex: 1,
        stepCount: _steps,
        title: tr('What is your name?'),
        subtitle: tr('So they know who the alert is about.'),
        onBack: _back,
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
      2 => StepScaffold(
        stepIndex: 2,
        stepCount: _steps,
        title: tr('Your phone number'),
        subtitle: tr('So they can call you straight from an alert.'),
        onBack: _back,
        onNext: _makeCode,
        onSkip: () {
          _phone.clear();
          _makeCode();
        },
        child: TextField(
          controller: _phone,
          autofocus: true,
          keyboardType: TextInputType.phone,
          style: t.titleLarge,
          decoration: InputDecoration(hintText: tr('Mobile number')),
        ),
      ),
      _ => _CodePage(
        code: _code,
        error: _error,
        busy: _busy,
        before: _before,
        onRetry: _makeCode,
        onBack: _busy ? null : () => setState(() => _step = 2),
      ),
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0 && _step < 3) _back();
        if (!didPop && _step == 3) context.pop();
      },
      child: Scaffold(
        body: StepSwitcher(index: _step, child: page),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: context.colorScheme.primaryContainer,
          child: Icon(icon, color: context.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: context.textTheme.titleMedium)),
      ],
    ),
  );
}

/// Shows the code and waits for the caretaker to type it in.
class _CodePage extends ConsumerWidget {
  const _CodePage({
    required this.code,
    required this.error,
    required this.busy,
    required this.before,
    required this.onRetry,
    required this.onBack,
  });

  final String? code;
  final String? error;
  final bool busy;
  final Set<String>? before;
  final VoidCallback onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final links = ref.watch(myCaretakersProvider).value ?? const <CareLink>[];
    final joined = [
      for (final l in links)
        if (before != null && !before!.contains(l.id)) l,
    ];

    if (joined.isNotEmpty) {
      final name = joined.first.caretakerLabel;
      return StepScaffold(
        stepIndex: 3,
        stepCount: 4,
        leading: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Icon(Icons.check_circle, size: 72, color: scheme.primary),
        ),
        title: trf('Connected to {n}', {'n': name}),
        subtitle: trf('{n} will now get an alert if you miss a medicine.', {
          'n': name,
        }),
        nextLabel: tr('Done'),
        onNext: () => context.pop(),
        child: const SizedBox.shrink(),
      );
    }

    final c = code;
    return StepScaffold(
      stepIndex: 3,
      stepCount: 4,
      title: tr('Show this code to them'),
      subtitle: tr(
        'On their phone: open Reindeer, choose "Look after someone", and type this code.',
      ),
      onBack: onBack,
      nextLabel: error != null ? tr('Try again') : tr('Cancel'),
      onNext: error != null ? onRetry : () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null)
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: AppSpacing.cardPadding,
                child: Text(
                  error!,
                  style: t.bodyLarge?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
            )
          else if (c == null || busy)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            FadeSlideIn(
              child: Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.lg,
                    horizontal: AppSpacing.sm,
                  ),
                  child: Semantics(
                    label: c.split('').join(' '),
                    child: Text(
                      '${c.substring(0, 3)} ${c.substring(3)}',
                      textAlign: TextAlign.center,
                      style: t.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(tr('Waiting for them...'), style: t.bodyLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              tr('The code works for 15 minutes.'),
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => SystemChannel.shareText(
                inEnglish(
                  () => trf(
                    'Please look after my medicines on Reindeer. Open the app, choose "Look after someone" and enter this code: {c}',
                    {'c': c},
                  ),
                ),
                title: tr('Send code'),
              ),
              icon: const Icon(Icons.share_outlined),
              label: Text(tr('Send code on WhatsApp or SMS')),
            ),
          ],
        ],
      ),
    );
  }
}
