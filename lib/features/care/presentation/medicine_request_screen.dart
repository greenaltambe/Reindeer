import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/i18n/strings.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/core/utils/date_time_utils.dart';
import 'package:reindeer/features/care/application/care_providers.dart';
import 'package:reindeer/features/care/data/care_backend.dart';
import 'package:reindeer/features/care/domain/care_models.dart';
import 'package:reindeer/shared/widgets/empty_state_view.dart';

final _requestProvider =
    FutureProvider.family<
      ({CareRequest? request, Uint8List? photo}),
      (String, String)
    >((ref, key) async {
      final (patientUid, id) = key;
      final request = await CareBackend.request(patientUid, id);
      Uint8List? photo;
      if (request?.hasPhoto ?? false) {
        final raw = await CareBackend.photo(patientUid, id);
        if (raw != null) photo = base64Decode(raw);
      }
      return (request: request, photo: photo);
    });

/// A patient's request to buy medicines, with the prescription photo.
class MedicineRequestScreen extends ConsumerStatefulWidget {
  const MedicineRequestScreen({
    super.key,
    required this.patientUid,
    required this.requestId,
  });

  final String patientUid;
  final String requestId;

  @override
  ConsumerState<MedicineRequestScreen> createState() =>
      _MedicineRequestScreenState();
}

class _MedicineRequestScreenState extends ConsumerState<MedicineRequestScreen> {
  bool _replied = false;
  bool _busy = false;

  Future<void> _reply() async {
    setState(() => _busy = true);
    try {
      await CareBackend.sendToPatient(widget.patientUid, 'onit');
      if (mounted) setState(() => _replied = true);
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
    final links = ref.watch(myPatientsProvider).value ?? const <CareLink>[];
    final link = links
        .where((l) => l.patientUid == widget.patientUid)
        .firstOrNull;
    final name = link?.patientLabel ?? tr('Your family member');
    final data = ref.watch(
      _requestProvider((widget.patientUid, widget.requestId)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(trf('{n} needs medicines', {'n': name}))),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyStateView(
          title: tr('Could not load'),
          message: tr('Check the internet and try again.'),
          icon: Icons.cloud_off_outlined,
        ),
        data: (d) {
          final request = d.request;
          if (request == null) {
            return EmptyStateView(
              title: tr('Request not found'),
              message: tr('It may be older than 30 days.'),
              icon: Icons.search_off,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                trf('Asked on {d} at {t}', {
                  'd': formatLongDate(request.createdAt),
                  't': formatTime(request.createdAt),
                }),
                style: t.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final item in request.items)
                      ListTile(
                        leading: const Icon(Icons.medication_outlined),
                        title: Text(item, style: t.titleMedium),
                      ),
                  ],
                ),
              ),
              if (d.photo != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(tr('Prescription'), style: t.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _PhotoView(bytes: d.photo!),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: AppSpacing.borderRadiusMd,
                    child: Image.memory(d.photo!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  tr('Tap the photo to zoom. Show it at the chemist.'),
                  style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: _replied || _busy ? null : _reply,
                icon: Icon(
                  _replied ? Icons.check : Icons.thumb_up_alt_outlined,
                ),
                label: Text(
                  _replied
                      ? trf('{n} knows you are on it', {'n': name})
                      : trf('Tell {n} I am getting them', {'n': name}),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PhotoView extends StatelessWidget {
  const _PhotoView({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(tr('Prescription')),
    ),
    body: InteractiveViewer(
      maxScale: 6,
      child: Center(child: Image.memory(bytes)),
    ),
  );
}
