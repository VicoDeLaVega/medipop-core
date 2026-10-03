import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/adapters.dart';
import '../runtime/providers.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

/// Entry point for app shells: each organization passes its own adapters.
void runMedipop(MedipopAdapters adapters, {String title = 'Medipop'}) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(
      overrides: [adaptersProvider.overrideWithValue(adapters)],
      child: MedipopApp(title: title)));
}

class MedipopApp extends ConsumerStatefulWidget {
  const MedipopApp({super.key, this.title = 'Medipop'});
  final String title;
  @override
  ConsumerState<MedipopApp> createState() => _MedipopAppState();
}

class _MedipopAppState extends ConsumerState<MedipopApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(workspaceProvider).initialize());
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(workspaceProvider);
    final workspace = controller.workspace;
    final identity = ref.watch(adaptersProvider).identity;
    final branding = workspace?.package.branding ?? const {};
    final seed = parseHexColor(branding['primaryColor'] as String?);
    final title = branding['name'] as String? ?? widget.title;
    // Replacing the navigator discards all patient-bearing routes on account changes/logout.
    return MaterialApp(
      key: ValueKey(
          '${workspace?.key}/${workspace?.package.id}/${workspace?.package.version}'),
      title: title,
      debugShowCheckedModeBanner: false,
      theme: seed == null ? buildLightTheme() : buildLightTheme(seed),
      darkTheme: seed == null ? buildDarkTheme() : buildDarkTheme(seed),
      home: controller.loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : workspace != null
              ? HomeScreen(title: title)
              : identity.requiresSignIn
                  ? Builder(
                      builder: (context) =>
                          identity.buildSignIn(context, controller.signedIn))
                  : _Unavailable(controller.error),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable(this.error);
  final String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error ?? 'Workspace unavailable.'))));
}
