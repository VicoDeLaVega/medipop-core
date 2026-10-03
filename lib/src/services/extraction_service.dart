import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../package/clinical_package.dart';
import '../runtime/providers.dart';
import 'llm_service.dart';

class ClinicalDraft {
  ClinicalDraft(this.package, this.transcript, this.values, {this.warning});
  final ClinicalPackage package;
  final String transcript;
  final Map<String, dynamic> values;
  final String? warning;
}

String extractJsonObject(String source) {
  var depth = 0;
  var quoted = false;
  var escaped = false;
  var start = -1;
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    if (start < 0) {
      if (c == '{') {
        start = i;
        depth = 1;
      }
      continue;
    }
    if (escaped) {
      escaped = false;
      continue;
    }
    if (quoted && c == r'\') {
      escaped = true;
      continue;
    }
    if (c == '"') {
      quoted = !quoted;
      continue;
    }
    if (!quoted) {
      if (c == '{') depth++;
      if (c == '}') depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  throw const FormatException('No complete JSON object.');
}

class ExtractionService {
  ExtractionService(this.llm, this.package);
  final LlmService llm;
  final ClinicalPackage package;
  Future<ClinicalDraft> extract(String transcript) async {
    final raw = await llm.complete(package.prompt(transcript));
    try {
      final decoded =
          jsonDecode(extractJsonObject(raw)) as Map<String, dynamic>;
      return ClinicalDraft(package, transcript, package.normalize(decoded));
    } on FormatException {
      return ClinicalDraft(package, transcript, package.normalize({}),
          warning:
              'The model did not return valid fields. Complete the form manually.');
    }
  }
}

final extractionServiceProvider = Provider.autoDispose<ExtractionService>(
    (ref) => ExtractionService(ref.watch(llmServiceProvider),
        ref.watch(workspaceProvider).workspace!.package));
