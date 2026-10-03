import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../runtime/providers.dart';
import '../../services/extraction_service.dart';
import '../../services/llm_service.dart';
import 'history_screen.dart';
import 'model_screen.dart';
import 'record_screen.dart';
import 'review_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.title = 'Medipop'});
  final String title;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(workspaceProvider);
    final workspace = controller.workspace!;
    final adapters = ref.watch(adaptersProvider);
    final signIn = adapters.identity.requiresSignIn;
    ref.watch(outboxProvider); // Keeps the scoped store and sync lifecycle alive.
    return Scaffold(
        appBar: AppBar(title: Text(title), actions: [
          if (signIn)
            IconButton(
                tooltip: 'Sign out',
                onPressed: controller.signOut,
                icon: const Icon(Icons.logout)),
        ]),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Text(workspace.package.title,
              style: Theme.of(context).textTheme.headlineMedium),
          Text(signIn
              ? 'Organization ${workspace.identity.organizationId} • ${workspace.identity.role}'
              : adapters.sync.enabled
                  ? 'This device'
                  : 'This device • data stays local, use export'),
          if (controller.error != null)
            Text(controller.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (controller.offline)
            const Text(
                'Offline workspace. Reconnect and sign in again if sync requires it.'),
          const SizedBox(height: 16),
          _ModelBanner(model: workspace.package.model),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecordScreen())),
              icon: const Icon(Icons.mic),
              label: const Text('Dictate consultation')),
          OutlinedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ReviewScreen(
                      draft: ClinicalDraft(workspace.package, '',
                          workspace.package.normalize({}))))),
              child: const Text('Enter fields manually')),
          OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen())),
              child: const Text('History & export')),
          OutlinedButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ModelScreen())),
              child: const Text('Install AI model')),
          if (adapters.sync.enabled)
            TextButton(
                onPressed: () => unawaited(ref.read(outboxProvider).flush()),
                child: const Text('Sync now')),
          if (signIn)
            TextButton(
                onPressed: controller.refreshConfiguration,
                child: const Text('Refresh organization configuration')),
          if (adapters.config.allowsLocalImport)
            TextButton(
                onPressed: () async {
                  try {
                    final file = await openFile(acceptedTypeGroups: [
                      const XTypeGroup(
                          label: 'Package JSON',
                          extensions: ['json'],
                          uniformTypeIdentifiers: ['public.json'])
                    ]);
                    if (file != null) {
                      await controller
                          .importPackage(await file.readAsString());
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Package not activated: $e')));
                    }
                  }
                },
                child: const Text('Load a package JSON')),
          const SizedBox(height: 24),
          const Text(
              'Review all extracted fields before saving. Speech recognition depends on the device and may require Internet.'),
        ]));
  }
}

/// Offers the organization's configured model when it is not installed yet,
/// so first launch leads straight to the download.
class _ModelBanner extends StatefulWidget {
  const _ModelBanner({required this.model});
  final Map<String, dynamic>? model;
  @override
  State<_ModelBanner> createState() => _ModelBannerState();
}

class _ModelBannerState extends State<_ModelBanner> {
  late Future<bool> installed = _check();

  Future<bool> _check() async {
    final hash = widget.model?['sha256'] as String?;
    if (hash == null) return true; // No model imposed by the configuration.
    final store = await LlmService.modelStore();
    return await store.activePath(expectedHash: hash) != null;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
      future: installed,
      builder: (context, snapshot) {
        if (snapshot.data != false) return const SizedBox.shrink();
        final name = widget.model?['name'] as String? ?? 'AI model';
        return Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI model required: $name',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text(
                          'Download it once over Wi-Fi to fill forms automatically. Manual entry works meanwhile.'),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                          onPressed: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const ModelScreen()));
                            if (mounted) setState(() => installed = _check());
                          },
                          child: const Text('Install model')),
                    ])));
      });
}
