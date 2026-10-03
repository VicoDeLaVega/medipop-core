/// Offline clinical dictation core. Organization-specific identity,
/// configuration and synchronization are provided by adapters.
library;

export 'src/adapters/adapters.dart';
export 'src/adapters/local.dart';
export 'src/data/consultation.dart';
export 'src/package/clinical_package.dart';
export 'src/runtime/providers.dart'
    show adaptersProvider, workspaceProvider;
export 'src/runtime/workspace.dart' show Workspace, WorkspaceController;
export 'src/ui/medipop_app.dart';
