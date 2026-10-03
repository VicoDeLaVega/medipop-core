import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/llm_service.dart';
import '../../services/model_store.dart';
import '../../runtime/providers.dart';

class ModelScreen extends ConsumerStatefulWidget {
  const ModelScreen({super.key});
  @override
  ConsumerState<ModelScreen> createState() => _ModelScreenState();
}

class _ModelScreenState extends ConsumerState<ModelScreen> {
  final url = TextEditingController(), hash = TextEditingController();
  bool busy = false;
  String? message;
  late final Future<ModelStore> store = LlmService.modelStore();
  @override
  void initState() {
    super.initState();
    final config = ref.read(workspaceProvider).workspace!.package.model;
    url.text = config?['url'] as String? ?? '';
    hash.text = config?['sha256'] as String? ?? '';
  }

  @override
  void dispose() {
    url.dispose();
    hash.dispose();
    super.dispose();
  }

  Future<void> install(bool local) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final modelStore = await store;
      if (local) {
        final file = await openFile();
        if (file == null) return;
        await modelStore.importFile(File(file.path), hash.text);
      } else {
        await modelStore.download(Uri.parse(url.text.trim()), hash.text);
      }
      if (mounted) {
        setState(() => message =
            'Model verified and installed. Local extraction is ready.');
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Installation failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configuredHash =
        ref.watch(workspaceProvider).workspace!.package.model?['sha256'];
    return Scaffold(
        appBar: AppBar(title: const Text('Local AI model')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Text(
              'Install a GGUF model independently of the app. Get its SHA-256 from your trusted model publisher or administrator. Extraction works locally after installation.'),
          const SizedBox(height: 16),
          TextField(
              controller: hash,
              readOnly: configuredHash != null || busy,
              decoration: const InputDecoration(labelText: 'Expected SHA-256')),
          TextField(
              controller: url,
              enabled: !busy,
              decoration: const InputDecoration(
                  labelText: 'Direct HTTPS download URL')),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: busy ? null : () => install(false),
              child: const Text('Download & verify')),
          OutlinedButton(
              onPressed: busy ? null : () => install(true),
              child: const Text('Import local GGUF')),
          if (busy) const LinearProgressIndicator(),
          if (message != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(message!)),
        ]));
  }
}
