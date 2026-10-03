import 'dart:convert';

class ClinicalPackage {
  ClinicalPackage._(this.json, this.fields);
  final Map<String, dynamic> json;
  final List<ClinicalField> fields;
  String get id => json['id'] as String;
  String get version => json['version'] as String;
  String get title => json['title'] as String;
  /// Dictation languages offered to the user, preferred first.
  List<String> get locales {
    final list = json['locales'];
    if (list is List && list.isNotEmpty) return List<String>.from(list);
    return [json['locale'] as String? ?? 'en_US'];
  }

  String get locale => locales.first;
  Map<String, dynamic>? get model => json['model'] as Map<String, dynamic>?;

  /// Organization identity shown after sign-in: name, primaryColor, logoUrl.
  Map<String, dynamic> get branding =>
      json['branding'] as Map<String, dynamic>? ?? const {};
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
    final locales = j['locales'];
    if (locales != null &&
        (locales is! List ||
            locales.isEmpty ||
            locales.any((l) =>
                l is! String || !RegExp(r'^[a-z]{2}(_[A-Z]{2})?$').hasMatch(l)) ||
            locales.toSet().length != locales.length)) {
      throw const FormatException('Locales must be unique codes like fr_FR.');
    }
    final branding = j['branding'];
    if (branding != null &&
        (branding is! Map<String, dynamic> ||
            (branding['name'] != null &&
                (branding['name'] is! String ||
                    (branding['name'] as String).isEmpty)) ||
            (branding['primaryColor'] != null &&
                (branding['primaryColor'] is! String ||
                    !RegExp(r'^#[0-9a-fA-F]{6}$')
                        .hasMatch(branding['primaryColor']))) ||
            (branding['logoUrl'] != null &&
                (branding['logoUrl'] is! String ||
                    Uri.tryParse(branding['logoUrl'])?.scheme != 'https')))) {
      throw const FormatException(
          'Branding accepts name, primaryColor (#RRGGBB) and an HTTPS logoUrl.');
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
  String prompt(String transcript, {String? locale}) =>
      (json['prompt'] as String)
          .replaceAll('{{SCHEMA}}', jsonEncode(json['fields']))
          .replaceAll('{{LANGUAGE}}', locale ?? this.locale)
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
  ClinicalField(this.id, this.labels, this.type, this.requiredValue,
      this.children, this.options);
  final String id, type;

  /// Label per language code ('fr', 'en'…); '' when the package gives one string.
  final Map<String, String> labels;
  String get label => labels['en'] ?? labels[''] ?? labels.values.first;
  String labelIn(String language) => labels[language] ?? label;
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
          _parseLabels(f['label']) == null ||
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
          _parseLabels(f['label'])!,
          f['type'],
          f['required'] == true,
          ['group', 'list'].contains(f['type'])
              ? parseList(f['fields'], depth + 1)
              : [],
          f['type'] == 'choice' ? List<String>.from(options) : []);
    }).toList();
  }

  static Map<String, String>? _parseLabels(dynamic raw) {
    if (raw is String) return raw.isEmpty ? null : {'': raw};
    if (raw is! Map || raw.isEmpty) return null;
    final labels = <String, String>{};
    for (final entry in raw.entries) {
      if (entry.key is! String ||
          !RegExp(r'^[a-z]{2}$').hasMatch(entry.key) ||
          entry.value is! String ||
          (entry.value as String).isEmpty) {
        return null;
      }
      labels[entry.key as String] = entry.value as String;
    }
    return labels;
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
