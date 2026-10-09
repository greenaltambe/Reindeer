import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/platform/system_channel.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/care/application/care_providers.dart';
import 'package:reindeer/features/care/data/care_backend.dart';
import 'package:reindeer/features/care/domain/care_models.dart';
import 'package:url_launcher/url_launcher.dart';

/// India's single emergency number.
const String emergencyNumber = '112';

/// Number in the international form WhatsApp links need (India by default).
String whatsappNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length == 10) digits = '91$digits';
  return digits;
}

/// The red Help button on Today. Shown only when someone looks after this
/// person, so it never clutters the app for people using it alone.
class HelpButton extends ConsumerWidget {
  const HelpButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caretakers =
        ref.watch(myCaretakersProvider).value ?? const <CareLink>[];
    if (caretakers.isEmpty) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xxs),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        onPressed: () => showHelpSheet(context),
        icon: const Icon(Icons.sos),
        label: Text(tr('Help')),
      ),
    );
  }
}

Future<void> showHelpSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const _HelpSheet(),
);

class _HelpSheet extends ConsumerStatefulWidget {
  const _HelpSheet();

  @override
  ConsumerState<_HelpSheet> createState() => _HelpSheetState();
}

class _HelpSheetState extends ConsumerState<_HelpSheet> {
  /// One alert a minute at most, even if the button is pressed again.
  static DateTime? _lastAlert;

  bool _busy = false;

  bool get _sent =>
      _lastAlert != null &&
      DateTime.now().difference(_lastAlert!) < const Duration(minutes: 1);

  Future<void> _alert() async {
    setState(() => _busy = true);
    try {
      await CareBackend.sendPatientEvent('sos');
      _lastAlert = DateTime.now();
    } catch (_) {
      if (mounted) {
        context.showSnackBar(
          tr('Could not send the alert. Please call instead.'),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _whatsapp(String phone) async {
    final text = Uri.encodeComponent(
      inEnglish(() => tr('I need help. Please call me.')),
    );
    final ok = await launchUrl(
      Uri.parse('https://wa.me/${whatsappNumber(phone)}?text=$text'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      context.showSnackBar(tr('WhatsApp is not installed.'), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textTheme;
    final scheme = context.colorScheme;
    final caretakers =
        ref.watch(myCaretakersProvider).value ?? const <CareLink>[];
    final names = caretakers.map((c) => c.caretakerLabel).join(', ');
    final sent = _sent;

    Widget bigButton({
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
      Color? background,
      Color? foreground,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(60),
          backgroundColor: background,
          foregroundColor: foreground,
          textStyle: t.titleMedium,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 26),
        label: Text(label),
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Need help?'), style: t.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            if (sent)
              Card(
                color: scheme.primaryContainer,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: AppSpacing.cardPadding,
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: scheme.onPrimaryContainer,
                        size: 32,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          trf('Alert sent. {n} has been told.', {'n': names}),
                          style: t.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              bigButton(
                icon: Icons.notifications_active,
                label: trf('Alert {n}', {'n': names}),
                background: scheme.error,
                foreground: scheme.onError,
                onPressed: _busy ? null : _alert,
              ),
            for (final c in caretakers)
              if (c.caretakerPhone.isNotEmpty) ...[
                bigButton(
                  icon: Icons.call,
                  label: trf('Call {n}', {'n': c.caretakerLabel}),
                  onPressed: () => SystemChannel.dial(c.caretakerPhone),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    textStyle: t.titleMedium,
                  ),
                  onPressed: () => _whatsapp(c.caretakerPhone),
                  icon: const Icon(Icons.chat_outlined),
                  label: Text(trf('WhatsApp {n}', {'n': c.caretakerLabel})),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            const Divider(height: AppSpacing.lg),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
                textStyle: t.titleMedium,
              ),
              onPressed: () => SystemChannel.dial(emergencyNumber),
              icon: const Icon(Icons.local_hospital_outlined),
              label: Text(tr('Call 112 (emergency)')),
            ),
          ],
        ),
      ),
    );
  }
}
