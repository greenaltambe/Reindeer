import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reindeer/core/constants/app_spacing.dart';
import 'package:reindeer/core/router/app_routes.dart';
import 'package:reindeer/core/utils/context_extensions.dart';
import 'package:reindeer/features/medications/application/strip_scanner.dart';
import 'package:reindeer/features/medications/application/voice_input.dart';
import 'package:reindeer/features/medications/domain/scan_candidates.dart';
import 'package:reindeer/features/medications/domain/shorthand_parser.dart';
import 'package:reindeer/features/medications/domain/spoken_normalizer.dart';
import 'package:reindeer/features/medications/presentation/add_draft.dart';
import 'package:reindeer/features/medicine_database/data/medicine_search_service.dart';
import 'package:reindeer/features/medicine_database/domain/models/medicine.dart';
import 'package:reindeer/core/i18n/strings.dart';

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
  final _voice = VoiceInput();
  bool _listening = false;
  bool _scanning = false;
  List<String> _otherLines = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _voice.cancel();
    _controller.dispose();
    super.dispose();
  }

  ParsedShorthand get _parsed => parseShorthand(_controller.text);

  void _onChanged(String raw) {
    _debounce?.cancel();
    setState(() {});
    final text = parseShorthand(raw).query;
    if (text.length < 2) {
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

  void _say(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _setText(String t) {
    _controller.text = t;
    _controller.selection = TextSelection.collapsed(offset: t.length);
    _onChanged(t);
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final ok = await _voice.init(
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted && _listening) {
          setState(() => _listening = false);
        }
      },
    );
    if (!mounted) return;
    if (!ok) {
      _say(
        tr('Voice is not available. Allow the microphone, or type instead.'),
      );
      return;
    }
    setState(() {
      _listening = true;
      _otherLines = const [];
    });
    try {
      await _voice.start(
        onWords: (words, done) {
          if (!mounted) return;
          final t = normalizeSpoken(words);
          if (t.isNotEmpty) _setText(t);
          if (done) setState(() => _listening = false);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _listening = false);
      _say(
        tr('Voice is not available. Allow the microphone, or type instead.'),
      );
    }
  }

  Future<void> _scan() async {
    final source = await showModalBottomSheet<ScanSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(tr('Take a photo of the strip')),
              onTap: () => Navigator.pop(ctx, ScanSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('Choose a photo')),
              onTap: () => Navigator.pop(ctx, ScanSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _scanning = true);
    try {
      final text = await scanPackageText(source);
      if (!mounted) return;
      if (text == null) {
        setState(() => _scanning = false);
        return;
      }
      final candidates = medicineNameCandidates(text);
      final service = await ref.read(medicineSearchProvider.future);
      String? best;
      for (final c in candidates.take(6)) {
        final hits = await service.search(c);
        if (hits.isNotEmpty) {
          best = c;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _otherLines = [
          for (final c in candidates)
            if (c != best) c,
        ];
      });
      if (best != null) {
        _setText(best);
      } else {
        _say(
          tr(
            'Could not read a medicine name. Try a clearer photo, or type it.',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _scanning = false);
      _say(tr('Could not read the photo. Please type the name instead.'));
    }
  }

  void _open(AddDraft draft) {
    final parsed = _parsed;
    context.push(
      AppRoutes.addDetails,
      extra: AddDraft(
        hit: draft.hit,
        customName: draft.customName,
        prefill: parsed.hasSchedule ? parsed : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final text = parsed.query;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Add medicine'))),
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
                hintText: tr('Name or salt, e.g. dolo 650 1-0-1 after food 5d'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_controller.text.isNotEmpty)
                      IconButton(
                        tooltip: tr('Clear'),
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _otherLines = const []);
                          _onChanged('');
                        },
                      ),
                    IconButton(
                      tooltip: tr('Say it'),
                      icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                      onPressed: _toggleVoice,
                    ),
                    IconButton(
                      tooltip: tr('Scan a strip or bottle'),
                      icon: const Icon(Icons.photo_camera_outlined),
                      onPressed: _scanning ? null : _scan,
                    ),
                  ],
                ),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_listening)
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
                  leading: const Icon(Icons.graphic_eq),
                  title: Text(
                    tr('Listening… say the medicine and how to take it'),
                  ),
                  subtitle: Text(
                    tr(
                      'For example: Dolo 650, morning and night after food, 5 days',
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: _toggleVoice,
                    child: Text(tr('Stop')),
                  ),
                ),
              ),
            ),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: LinearProgressIndicator(),
            ),
          if (_otherLines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    Text(
                      tr('Other text on the pack:'),
                      style: context.textTheme.labelLarge,
                    ),
                    for (final c in _otherLines.take(5))
                      ActionChip(label: Text(c), onPressed: () => _setText(c)),
                  ],
                ),
              ),
            ),
          if (parsed.hasSchedule)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Card(
                color: context.colorScheme.primaryContainer,
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.auto_awesome,
                    color: context.colorScheme.onPrimaryContainer,
                  ),
                  title: Text(
                    trf('Understood: {n}', {'n': parsed.summary}),
                    style: TextStyle(
                      color: context.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  subtitle: Text(
                    tr('Pick the medicine and it will be filled in for you.'),
                    style: TextStyle(
                      color: context.colorScheme.onPrimaryContainer,
                    ),
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
            tr(
              'Type the name on the strip or bottle. Spelling does not have to be exact, and you can also type the salt names (for example "ambroxol guaifenesin").\n\nTip: copy the doctor\'s line as written, like "pan 40 1-0-0 before food 14 days". Reindeer reads the schedule for you.',
            ),
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
            trf('No match found for "{n}".', {'n': text}),
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tr('Check the spelling, or add it yourself.'),
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
        title: Text(tr("Can't find it? Add it yourself")),
        subtitle: Text(
          tr('You will type the name; it is marked as not from the list.'),
        ),
        onTap: () => _open(AddDraft(customName: name)),
      ),
    );
  }
}
