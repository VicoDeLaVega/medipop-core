import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medipop_core/medipop_core.dart';
import 'package:medipop_core/src/data/consultation_store.dart';
import 'package:medipop_core/src/runtime/outbox.dart';
import 'package:medipop_core/src/ui/widgets/clinical_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

final examplePackage = ClinicalPackage.parse(
    File('assets/packages/example-prescription.json').readAsStringSync());

const doctorA = Identity(userId: 'user-a', organizationId: 'org-a', role: 'doctor');
const doctorB = Identity(userId: 'user-b', organizationId: 'org-b', role: 'doctor');

class FakeIdentity implements IdentityProvider {
  FakeIdentity({this.identity = doctorA, this.allowed = true});
  Identity? identity;
  bool allowed;
  @override
  bool get requiresSignIn => true;
  @override
  Future<Identity?> restore() async => identity;
  @override
  Widget buildSignIn(BuildContext context, onSignedIn) =>
      const Text('Fake sign-in');
  @override
  Future<bool> authorize(Identity identity) async => allowed;
  @override
  Stream<void> get signedOut => const Stream.empty();
  @override
  Future<void> signOut() async => identity = null;
}

class FakeConfig extends ConfigSource {
  bool offline = false;
  @override
  Future<ClinicalPackage> load(Identity identity) async {
    if (offline) throw const OfflineException();
    return examplePackage;
  }
}

class RecordingSync implements SyncTarget {
  final sent = <String>[];
  bool fail = false;
  @override
  bool get enabled => true;
  @override
  Future<void> send(Consultation record, Identity identity) async {
    if (fail) throw StateError('refused');
    sent.add(record.id);
  }
}

Consultation recordFor(Identity identity) => Consultation.create(
    userId: identity.userId,
    organizationId: identity.organizationId,
    deviceId: 'device',
    package: examplePackage,
    transcript: 'Fictitious',
    payload: examplePackage.normalize({}));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('standalone adapters open the workspace without sign-in',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [adaptersProvider.overrideWithValue(localAdapters())],
        child: const MedipopApp()));
    await tester.pumpAndSettle();
    expect(find.text('History & export'), findsOneWidget);
    expect(find.text('Sync now'), findsNothing);
    expect(find.byTooltip('Sign out'), findsNothing);
  });

  testWidgets('sign-in providers show their own screen when no identity',
      (tester) async {
    final adapters = MedipopAdapters(
        identity: FakeIdentity(identity: null),
        config: FakeConfig(),
        sync: RecordingSync());
    await tester.pumpWidget(ProviderScope(
        overrides: [adaptersProvider.overrideWithValue(adapters)],
        child: const MedipopApp()));
    await tester.pumpAndSettle();
    expect(find.text('Fake sign-in'), findsOneWidget);
  });

  testWidgets('dynamic form keeps remaining list item after deletion',
      (tester) async {
    final values = examplePackage.normalize({
      'medications': [
        {'name': 'First'},
        {'name': 'Second'}
      ]
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ClinicalForm(
                    fields: examplePackage.fields, values: values)))));
    await tester.ensureVisible(find.byIcon(Icons.delete_outline).first);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    expect((values['medications'] as List).single['name'], 'Second');
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  test('identity scopes differ per account and organization', () {
    expect(doctorA.key, isNot(doctorB.key));
    expect(
        doctorA.key,
        isNot(const Identity(
                userId: 'user-a', organizationId: 'org-b', role: 'doctor')
            .key));
  });

  test('invalid package import leaves the active package unchanged', () async {
    final controller = WorkspaceController(MedipopAdapters(
        identity: LocalIdentity(),
        config: BundledConfigSource(),
        sync: const NoSync()));
    controller.workspace = Workspace(doctorA, examplePackage);
    await expectLater(
        controller.importPackage(jsonEncode({'formatVersion': 99})),
        throwsFormatException);
    expect(controller.workspace!.package.id, 'example-prescription');
    controller.dispose();
  });

  test('offline configuration falls back to the cached package only', () async {
    final config = FakeConfig()..offline = true;
    final controller = WorkspaceController(MedipopAdapters(
        identity: FakeIdentity(), config: config, sync: RecordingSync()));
    await controller.initialize();
    expect(controller.workspace, isNull, reason: 'No cache on first run');
    expect(controller.error, contains('Internet'));

    config.offline = false;
    await controller.signedIn(doctorA);
    expect(controller.offline, isFalse);
    config.offline = true;
    await controller.refreshConfiguration();
    expect(controller.workspace!.package.id, 'example-prescription');
    expect(controller.offline, isTrue);
    controller.dispose();
  });

  test('outbox sends once, keeps failures and never sends foreign records',
      () async {
    final store = ConsultationStore(NativeDatabase.memory());
    final sync = RecordingSync();
    final provider = FakeIdentity();
    final outbox = Outbox(store, doctorA, provider, sync,
        connectivity: const Stream.empty());
    final mine = recordFor(doctorA), foreign = recordFor(doctorB);
    await store.save(mine);
    await store.save(foreign);

    provider.allowed = false;
    await outbox.flush();
    expect(sync.sent, isEmpty, reason: 'Unauthorized identity suspends sync');

    provider.allowed = true;
    sync.fail = true;
    await outbox.flush();
    expect((await store.pending()).map((r) => r.id), contains(mine.id));

    sync.fail = false;
    await outbox.flush();
    await outbox.flush();
    expect(sync.sent, [mine.id]);
    expect((await store.pending()).single.id, foreign.id);
    outbox.dispose();
    await store.close();
  });
}
