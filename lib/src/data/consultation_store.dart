import 'dart:convert';
import 'package:drift/drift.dart';
import 'consultation.dart';

/// Separate SQLite file per account and organization. Legacy medipop.sqlite is untouched.
class ConsultationStore extends GeneratedDatabase {
  ConsultationStore(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [];
  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (_) async {
        await customStatement(
            'CREATE TABLE consultations (id TEXT PRIMARY KEY, envelope TEXT NOT NULL, sent_at TEXT, last_error TEXT)');
      });
  Future<void> save(Consultation record) => customStatement(
      'INSERT INTO consultations (id, envelope) VALUES (?, ?) ON CONFLICT(id) DO NOTHING',
      [record.id, record.encode()]);
  Future<List<Map<String, dynamic>>> rows() async =>
      (await customSelect('SELECT * FROM consultations ORDER BY rowid DESC')
              .get())
          .map((r) => {
                ...jsonDecode(r.read<String>('envelope'))
                    as Map<String, dynamic>,
                'sent_at': r.readNullable<String>('sent_at'),
                'last_error': r.readNullable<String>('last_error'),
              })
          .toList();
  Future<List<Consultation>> pending() async => (await customSelect(
              'SELECT envelope FROM consultations WHERE sent_at IS NULL ORDER BY rowid')
          .get())
      .map((r) => Consultation(jsonDecode(r.read<String>('envelope'))))
      .toList();
  Future<void> markSent(String id) => customStatement(
      'UPDATE consultations SET sent_at = ?, last_error = NULL WHERE id = ?',
      [DateTime.now().toUtc().toIso8601String(), id]);
  Future<void> markError(String id, String error) => customStatement(
      'UPDATE consultations SET last_error = ? WHERE id = ?', [error, id]);
}
