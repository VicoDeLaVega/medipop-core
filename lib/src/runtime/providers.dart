import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/adapters.dart';
import '../data/consultation_store.dart';
import 'outbox.dart';
import 'workspace.dart';

/// Overridden by the app shell with the organization's adapters.
final adaptersProvider = Provider<MedipopAdapters>(
    (ref) => throw UnimplementedError('Provide MedipopAdapters via runMedipop.'));

final workspaceProvider = ChangeNotifierProvider<WorkspaceController>(
    (ref) => WorkspaceController(ref.watch(adaptersProvider)));

final consultationStoreProvider =
    Provider.autoDispose<ConsultationStore>((ref) {
  final scope = ref.watch(workspaceProvider.select((w) => w.workspace?.key));
  if (scope == null) throw StateError('No open workspace.');
  // One SQLite file per identity scope; name kept stable across versions.
  final store = ConsultationStore(driftDatabase(name: 'medipop_v3_$scope'));
  ref.onDispose(store.close);
  return store;
});

final outboxProvider = Provider.autoDispose<Outbox>((ref) {
  final identity = ref.watch(workspaceProvider
      .select((w) => w.workspace?.identity));
  if (identity == null) throw StateError('No open workspace.');
  final adapters = ref.watch(adaptersProvider);
  final outbox = Outbox(ref.watch(consultationStoreProvider), identity,
      adapters.identity, adapters.sync);
  ref.onDispose(outbox.dispose);
  return outbox;
});
