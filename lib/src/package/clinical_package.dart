import 'dart:convert';

class ClinicalPackage {
  ClinicalPackage._(this.json, this.fields);
  final Map<String, dynamic> json;
  final List<ClinicalField> fields;
  String get id => json['id'] as String;
  String get version => json['version'] as String;
  String get title => json['title'] as String;
  String get locale => json['locale'] as String? ?? 'en_US';
  Map<String, dynamic>? get model => json['model'] as Map<String, dynamic>?;
  factory ClinicalPackage.parse(String source) {
    final j = jsonDecode(source);
    if (j is! Map<String, dynamic> || j['formatVersion'] != 1) {
      throw const FormatException('Unsupported package format (expected 1).');
    }
    for (final key in ['id', 'version', 'title', 'prompt']) {
      if (j[key] is! String || (j[key] as String).trim().isEmpty) {
        throw FormatException('Missing package $key.');
      }
    }
    if (!(j['prompt'] as String).contains('{{TRANSCRIPT}}') ||
        !(j['prompt'] as String).contains('{{SCHEMA}}')) {
      throw const FormatException(
          'Prompt requires TRANSCRIPT and SCHEMA placeholders.');
    }
    final fields = ClinicalField.parseList(j['fields'], 0);
    if (j['model'] != null) {
      final m = j['model'];
      if (m is! Map<String, dynamic> ||
          m['sha256'] is! String ||
          !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(m['sha256'] as String)) {
        throw const FormatException('Model requires a real SHA-256 digest.');
      }
      if (m['url'] != null &&
          (m['url'] is! String || Uri.tryParse(m['url'])?.scheme != 'https')) {
        throw const FormatException('Model URL must use HTTPS.');
      }
    }
    return ClinicalPackage._(j, fields);
  }
  String encode() => jsonEncode(json);
  String prompt(String transcript) => (json['prompt'] as String)
      .replaceAll('{{SCHEMA}}', jsonEncode(json['fields']))
      .replaceAll('{{TRANSCRIPT}}', transcript);
  Map<String, dynamic> normalize(Map<String, dynamic> values) => {
        for (final field in fields) field.id: field.normalize(values[field.id]),
      };
  List<String> validate(Map<String, dynamic> values) => [
        for (final field in fields)
          ...field.validate(values[field.id], field.label),
      ];
}

class ClinicalField {
  ClinicalField(this.id, this.label, this.type, this.requiredValue,
      this.children, this.options);
  final String id, label, type;
  final bool requiredValue;
  final List<ClinicalField> children;
  final List<String> options;
  static List<ClinicalField> parseList(dynamic raw, int depth) {
    if (depth > 8 || raw is! List || raw.isEmpty || raw.length > 100) {
      throw const FormatException('Invalid field list or nesting depth.');
    }
    final ids = <String>{};
    return raw.map((f) {
      if (f is! Map<String, dynamic> ||
          f['id'] is! String ||
          !RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(f['id']) ||
          !ids.add(f['id']) ||
          f['label'] is! String ||
          (f['label'] as String).isEmpty ||
          !['text', 'number', 'boolean', 'choice', 'group', 'list']
              .contains(f['type']) ||
          (f['required'] != null && f['required'] is! bool)) {
        throw const FormatException('Invalid, duplicate or unsupported field.');
      }
      final options = f['options'];
      if (f['type'] == 'choice' &&
          (options is! List ||
              options.isEmpty ||
              options.any((o) => o is! String || o.isEmpty) ||
              options.toSet().length != options.length)) {
        throw const FormatException('Choice requires unique text options.');
      }
      return ClinicalField(
          f['id'],
          f['label'],
          f['type'],
          f['required'] == true,
          ['group', 'list'].contains(f['type'])
              ? parseList(f['fields'], depth + 1)
              : [],
          f['type'] == 'choice' ? List<String>.from(options) : []);
    }).toList();
  }

  dynamic normalize(dynamic value) {
    switch (type) {
      case 'group':
        return {
          for (final f in children)
            f.id: f.normalize(value is Map ? value[f.id] : null)
        };
      case 'list':
        return value is List
            ? value
                .whereType<Map>()
                .map((v) => {
                      for (final f in children) f.id: f.normalize(v[f.id]),
                    })
                .toList()
            : <Map<String, dynamic>>[];
      case 'number':
        return value is num && value.isFinite ? value : null;
      case 'boolean':
        return value is bool ? value : null;
      case 'choice':
        return options.contains(value) ? value : null;
      default:
        return value is String ? value : null;
    }
  }

  List<String> validate(dynamic value, String path) {
    final errors = <String>[];
    if (requiredValue &&
        (value == null || value == '' || value is List && value.isEmpty)) {
      errors.add('$path is required.');
    }
    if (type == 'group' && value is Map) {
      for (final f in children) {
        errors.addAll(f.validate(value[f.id], '$path / ${f.label}'));
      }
    } else if (type == 'list' && value is List) {
      for (var i = 0; i < value.length; i++) {
        for (final f in children) {
          errors.addAll(
              f.validate(value[i][f.id], '$path ${i + 1} / ${f.label}'));
        }
      }
    } else if (value != null) {
      if (type == 'number' && (value is! num || !value.isFinite) ||
          type == 'boolean' && value is! bool ||
          type == 'choice' && !options.contains(value)) {
        errors.add('$path is invalid.');
      }
    }
    return errors;
  }
}
