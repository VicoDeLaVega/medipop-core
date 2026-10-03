import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../adapters/adapters.dart';
import '../data/consultation_store.dart';

/// Sends validated records through the configured [SyncTarget] when online.
/// Records stay pending until acknowledged; nothing is ever sent under an
/// identity other than the one that created it.
class Outbox {
  Outbox(this.store, this.identity, this.provider, this.target,
      {Stream<List<ConnectivityResult>>? connectivity}) {
    if (target.enabled) {
      _subscription = (connectivity ?? Connectivity().onConnectivityChanged)
          .listen((states) {
        if (states.any((s) => s != ConnectivityResult.none)) unawaited(flush());
      });
    }
  }
  final ConsultationStore store;
  final Identity identity;
  final IdentityProvider provider;
  final SyncTarget target;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _busy = false, _disposed = false;

  Future<void> flush() async {
    if (!target.enabled || _busy || _disposed) return;
    _busy = true;
    try {
      if (!await provider.authorize(identity)) return;
      for (final record in await store.pending()) {
        if (_disposed) break;
        if (record.userId != identity.userId ||
            record.organizationId != identity.organizationId) {
          await store.markError(
              record.id, 'Attribution mismatch; record not sent.');
          continue;
        }
        try {
          await target.send(record, identity);
          if (!_disposed) await store.markSent(record.id);
        } catch (_) {
          if (!_disposed) {
            await store.markError(
                record.id, 'Sync refused or offline. Sign in and retry.');
          }
          break;
        }
      }
    } catch (_) {
      // Keep the whole outbox while authentication or network is unavailable.
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
  }
}
