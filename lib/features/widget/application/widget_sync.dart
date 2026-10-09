import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reindeer/core/platform/system_channel.dart';
import 'package:reindeer/features/adherence/application/dose_actions.dart';
import 'package:reindeer/features/adherence/application/timeline_providers.dart';
import 'package:reindeer/features/widget/domain/widget_payload.dart';

/// Keeps the Android home-screen widget in step with the app.
///
/// Pushes the latest doses whenever they change, and applies doses that were
/// ticked off on the widget while the app was closed.
class WidgetSync with WidgetsBindingObserver {
  WidgetSync(this._ref);

  final Ref _ref;
  String? _last;
  bool _applying = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    _ref.listen(upcomingEntriesProvider, (_, next) {
      final entries = next.value;
      if (entries == null) return;
      final text = buildWidgetPayload(entries, DateTime.now()).encode();
      if (text == _last) return;
      _last = text;
      SystemChannel.updateWidget(text);
    }, fireImmediately: true);
    applyPending();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) applyPending();
  }

  /// Marks doses ticked off on the widget as taken.
  Future<void> applyPending() async {
    if (_applying) return;
    _applying = true;
    try {
      final keys = await SystemChannel.takeWidgetActions();
      if (keys.isEmpty) return;
      final entries = await _ref.read(upcomingEntriesProvider.future);
      for (final key in keys.toSet()) {
        for (final e in entries) {
          if (e.dose.key == key && e.isOpen) {
            await _ref.read(doseActionsProvider).take(e.dose);
            break;
          }
        }
      }
    } catch (_) {
      // The widget row is simply not applied; the dose stays on Today.
    } finally {
      _applying = false;
    }
  }
}

final widgetSyncProvider = Provider<WidgetSync>((ref) {
  final sync = WidgetSync(ref);
  sync.start();
  return sync;
});
