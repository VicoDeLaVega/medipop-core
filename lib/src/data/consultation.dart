import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../package/clinical_package.dart';

class Consultation {
  Consultation(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get organizationId => data['organization_id'] as String;
  String get userId => data['created_by_user_id'] as String;
  String get transcript => data['raw_transcript'] as String;
  Map<String, dynamic> get payload =>
      Map<String, dynamic>.from(data['payload']);
  factory Consultation.create(
      {required String userId,
      required String organizationId,
      required String deviceId,
      required ClinicalPackage package,
      required String transcript,
      required Map<String, dynamic> payload,
      String? id,
      String? createdAt,
      String? legacyId}) {
    final now = DateTime.now().toUtc().toIso8601String();
    return Consultation({
      'id': id ?? const Uuid().v4(),
      'organization_id': organizationId,
      'created_by_user_id': userId,
      'device_id': deviceId,
      'schema_id': package.id,
      'schema_version': package.version,
      'schema_snapshot': package.json,
      'payload': payload,
      'raw_transcript': transcript,
      'created_at': createdAt ?? now,
      'validated_at': now,
      'updated_at': now,
      'status': 'validated',
      if (legacyId != null) 'legacy_source_id': legacyId,
    });
  }
  String encode() => jsonEncode(data);
}
