import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/barcode/data/barcode_link_repository.dart';
import 'package:reindeer/features/barcode/domain/gs1.dart';
import 'package:reindeer/features/medications/presentation/add_draft.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';

/// Step 1 of adding a medicine: find it by brand or by salt name.
class AddSearchScreen extends ConsumerStatefulWidget {
  const AddSearchScreen({super.key});

  @override
  ConsumerState<AddSearchScreen> createState() => _AddSearchScreenState();
}

class _AddSearchScreenState extends ConsumerState<AddSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<MedicineHit> _results = const [];
  bool _searched = false;
  bool _loading = false;
  int _generation = 0;
  String? _pendingBarcode;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      _generation++;
      setState(() {
        _results = const [];
        _searched = false;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () => _run(text));
  }

  Future<void> _run(String text) async {
    final gen = ++_generation;
    setState(() => _loading = true);
    try {
      final service = await ref.read(medicineSearchProvider.future);
      // While typing, the last word is treated as a prefix ("pant" -> pantop).
      final hits = await service.search(text, asYouType: true);
      if (!mounted || gen != _generation) return;
      setState(() {
        _results = hits;
        _searched = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _results = const [];
        _searched = true;
        _loading = false;
      });
    }
  }

  void _open(AddDraft draft) => context.push(
    AppRoutes.addDetails,
    extra: AddDraft(
      hit: draft.hit,
      customName: draft.customName,
      barcode: draft.barcode ?? _pendingBarcode,
    ),
  );

  Future<void> _scan() async {
    final raw = await context.push<String>(AppRoutes.scan);
    if (raw == null || !mounted) return;
    final key = barcodeKey(raw);
    final id = await ref.read(barcodeLinkRepositoryProvider).find(key);
    if (id != null) {
      final service = await ref.read(medicineSearchProvider.future);
      final hit = await service.byId(id);
      if (hit != null && mounted) {
        context.push(
          AppRoutes.addDetails,
          extra: AddDraft(hit: hit, barcode: key),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() => _pendingBarcode = key);
    context.showSnackBar(
      'New pack. Search for it once and Reindeer will remember it.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add medicine'),
        actions: [
          IconButton(
            tooltip: 'Scan barcode',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scan,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: context.textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: 'Medicine name or salt, e.g. dolo 650',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _controller.clear();
                                _onChanged('');
                              },
                            )),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_pendingBarcode != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Card(
                color: context.colorScheme.tertiaryContainer,
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.qr_code_2,
                    color: context.colorScheme.onTertiaryContainer,
                  ),
                  title: Text(
                    'Pack scanned. Find the medicine below and Reindeer will remember this pack.',
                    style: TextStyle(
                      color: context.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _pendingBarcode = null),
                  ),
                ),
              ),
            ),
          Expanded(child: _body(context, text)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, String text) {
    if (text.length < 2) {
      return ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text(
            'Type the name on the strip or bottle. Spelling does not have to be exact, '
            'and you can also type the salt names (for example "ambroxol guaifenesin").',
            style: context.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          _customTile(context, ''),
        ],
      );
    }
    if (_searched && _results.isEmpty) {
      return ListView(
        padding: AppSpacing.screenPadding,
        children: [
          Text(
            'No match found for "$text".',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Check the spelling, or add it yourself.',
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          _customTile(context, text),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: _results.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, i) {
        if (i == _results.length) return _customTile(context, text);
        final hit = _results[i];
        return Card(
          child: ListTile(
            title: Text(hit.name, style: context.textTheme.titleMedium),
            subtitle: Text(
              hit.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(AddDraft(hit: hit)),
          ),
        );
      },
    );
  }

  Widget _customTile(BuildContext context, String name) {
    return Card(
      color: context.colorScheme.secondaryContainer.withValues(alpha: 0.5),
      child: ListTile(
        leading: const Icon(Icons.edit_note),
        title: const Text("Can't find it? Add it yourself"),
        subtitle: const Text(
          'You will type the name; it is marked as not from the list.',
        ),
        onTap: () => _open(AddDraft(customName: name)),
      ),
    );
  }
}
