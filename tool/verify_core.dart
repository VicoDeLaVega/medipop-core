import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:medipop_core/src/package/clinical_package.dart';
import 'package:medipop_core/src/data/consultation.dart';
import 'package:medipop_core/src/data/consultation_store.dart';
import 'package:medipop_core/src/services/model_store.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> mustFail(Future<void> Function() action) async {
  var failed = false;
  try {
    await action();
  } catch (_) {
    failed = true;
  }
  check(failed, 'Expected rejection');
}

Future<void> main() async {
  // Pure Dart (no Flutter): run from the package root or pass its path.
  final root = Platform.script.resolve('..').toFilePath();
  final source = await File('${root}assets/packages/example-prescription.json')
      .readAsString();
  final package = ClinicalPackage.parse(source);
  for (final mutation in [
    (Map<String, dynamic> j) {
      j['formatVersion'] = 2;
    },
    (Map<String, dynamic> j) {
      j['fields'][0]['type'] = 'code';
    },
    (Map<String, dynamic> j) {
      j['fields'][0]['fields'].add(j['fields'][0]['fields'][0]);
    },
    (Map<String, dynamic> j) {
      j.remove('id');
    },
  ]) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    mutation(j);
    await mustFail(() async {
      ClinicalPackage.parse(jsonEncode(j));
    });
  }
  check(package.normalize({})['medications'] is List, 'Empty lists');
  check(package.locales.first == 'en_US' && package.locales.contains('fr_FR'),
      'Declared dictation languages');
  check(package.prompt('x', locale: 'fr_FR').contains('fr_FR') &&
          !package.prompt('x').contains('{{LANGUAGE}}'),
      'Language placeholder filled');
  check(package.fields.first.labelIn('fr') == 'Patient' &&
          package.fields[2].labelIn('fr') == 'Médicaments' &&
          package.fields[2].labelIn('de') == 'Medications',
      'Localized labels with fallback');
  for (final bad in [
    {'locales': []},
    {'locales': ['french']},
    {'locales': ['fr_FR', 'fr_FR']},
  ]) {
    await mustFail(() async {
      ClinicalPackage.parse(jsonEncode({...jsonDecode(source), ...bad}));
    });
  }
  await mustFail(() async {
    final j = jsonDecode(source) as Map<String, dynamic>;
    j['fields'][0]['label'] = {'english': 'Patient'};
    ClinicalPackage.parse(jsonEncode(j));
  });
  check(
      package
          .validate(package.normalize({
            'medications': [{}]
          }))
          .isNotEmpty,
      'Required medication name');
  final schema = ClinicalPackage.parse(jsonEncode({
    ...jsonDecode(source),
    'fields': [
      {'id': 'score', 'label': 'Score', 'type': 'number'},
      {'id': 'done', 'label': 'Done', 'type': 'boolean'},
      {
        'id': 'choice',
        'label': 'Choice',
        'type': 'choice',
        'options': ['A', 'B']
      },
    ]
  }));
  check(
      schema.normalize(
              {'score': 'bad', 'done': false, 'choice': 'invalid'})['done'] ==
          false,
      'Boolean false retained');
  check(schema.normalize({'choice': 'invalid'})['choice'] == null,
      'Unknown choice rejected');
  final a = ConsultationStore(NativeDatabase.memory()),
      b = ConsultationStore(NativeDatabase.memory());
  final record = Consultation.create(
      userId: 'user-a',
      organizationId: 'org-a',
      deviceId: 'device-a',
      package: package,
      transcript: 'Fictitious',
      payload: package.normalize({}));
  await a.save(record);
  await a.save(record);
  check((await a.pending()).length == 1, 'Idempotent local insert');
  check((await b.rows()).isEmpty, 'Separate stores do not expose data');
  await a.markError(record.id, 'offline');
  check((await a.pending()).length == 1, 'Failure retains pending record');
  await a.markSent(record.id);
  check((await a.pending()).isEmpty,
      'Successful acknowledgement removes from pending');
  check(
      (await a.rows()).single['schema_version'] == package.version,
      'Schema preserved');
  await a.close();
  await b.close();
  final temp = await Directory.systemTemp.createTemp('medipop-model-test-');
  try {
    final store = ModelStore(temp);
    final bytes = utf8.encode('GGUFfictitious fixture, not a real model');
    final hash = sha256.convert(bytes).toString();
    check(await store.activePath() == null, 'No model initially');
    final path = await store.install(Stream.value(bytes), hash);
    check(await store.activePath() == path, 'Verified model activated');
    await mustFail(() async {
      await store.install(Stream.value(utf8.encode('corrupt')), hash);
    });
    check(await store.activePath() == path, 'Wrong hash preserves model');
    await mustFail(() async {
      await store.install(
          Stream.error(const SocketException('interrupted')), hash);
    });
    check(await ModelStore(temp).activePath() == path,
        'Restart preserves model after interruption');
    check(await store.activePath(expectedHash: '0' * 64) == null,
        'Wrong organization model not used');
    await mustFail(() async {
      await store.download(Uri.parse('http://example.invalid/model'), hash);
    });
    check(
        (await temp.list().toList())
            .whereType<File>()
            .every((f) => !f.path.endsWith('.part')),
        'No partial model remains');
  } finally {
    await temp.delete(recursive: true);
  }
  stdout.writeln(
      'PASS: package validation, field types, stable records, scoped stores, outbox retry, schema version, model hash, interruption and restart.');
}
