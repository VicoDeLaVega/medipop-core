import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'model_store.dart';
import '../runtime/providers.dart';

/// Removes `<think>…</think>` blocks (or an unterminated one) that some
/// reasoning models still emit, so braces inside them never reach JSON parsing.
String stripReasoning(String text) => text
    .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
    .replaceAll(RegExp(r'<think>[\s\S]*$'), '')
    .trim();

class LlmService {
  LlmService({this.expectedHash});
  final String? expectedHash;
  LlamaEngine? _engine;
  String? _loadedPath;
  static Future<ModelStore> modelStore() async {
    final dir = await getApplicationSupportDirectory();
    return ModelStore(Directory('${dir.path}/models'));
  }

  Future<String> complete(String prompt) async {
    final path =
        await (await modelStore()).activePath(expectedHash: expectedHash);
    if (path == null) {
      throw StateError('Install the configured AI model from Home first.');
    }
    if (_loadedPath != path) {
      await dispose();
      final engine = LlamaEngine(LlamaBackend());
      await engine.loadModel(path);
      _engine = engine;
      _loadedPath = path;
    }
    // The GGUF's own chat template keeps packages model-agnostic: any instruct
    // model (Qwen, Gemma, Llama, Mistral…) receives the prompt in its native format.
    // Reasoning is disabled and reasoning deltas are dropped so only the answer is parsed.
    final result = StringBuffer();
    await for (final chunk in _engine!.create(
      [LlamaChatMessage.fromText(role: LlamaChatRole.user, text: prompt)],
      params: const GenerationParams(temp: 0.2, maxTokens: 2048, topP: 0.9),
      enableThinking: false,
    )) {
      for (final choice in chunk.choices) {
        final content = choice.delta.content;
        if (content != null) result.write(content);
      }
    }
    return stripReasoning(result.toString());
  }

  Future<void> dispose() async {
    final old = _engine;
    _engine = null;
    _loadedPath = null;
    await old?.dispose();
  }
}

final llmServiceProvider = Provider.autoDispose<LlmService>((ref) {
  final hash =
      ref.watch(workspaceProvider).workspace?.package.model?['sha256'] as String?;
  final service = LlmService(expectedHash: hash);
  ref.onDispose(service.dispose);
  return service;
});
