import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../adapters/adapters.dart';
import '../package/clinical_package.dart';

/// The identity and package currently in use.
class Workspace {
  const Workspace(this.identity, this.package);
  final Identity identity;
  final ClinicalPackage package;
  String get key => identity.key;
}

/// Opens a workspace from the configured adapters. Holds no provider-specific
/// logic: sign-in, membership and package origin belong to the adapters.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this.adapters);
  final MedipopAdapters adapters;

  Workspace? workspace;
  bool loading = true;
  String? error;

  /// True when the package comes from the device cache because the
  /// configuration source was unreachable.
  bool offline = false;

  // Discards results of operations superseded by a newer sign-in/out.
  int _epoch = 0;
  StreamSubscription<void>? _signedOut;

  IdentityProvider get _identity => adapters.identity;

  Future<void> initialize() async {
    _signedOut = _identity.signedOut.listen((_) => _close());
    final epoch = ++_epoch;
    try {
      final identity = await _identity.restore();
      if (identity != null) await _open(identity, epoch);
    } catch (e) {
      if (epoch == _epoch) error = 'Unable to restore session: $e';
    } finally {
      if (epoch == _epoch) {
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Called by the identity provider's sign-in screen.
  Future<void> signedIn(Identity identity) async {
    final epoch = ++_epoch;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _open(identity, epoch);
    } catch (e) {
      if (epoch == _epoch) error = 'Unable to open workspace: $e';
    } finally {
      if (epoch == _epoch) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshConfiguration() async {
    final current = workspace;
    if (current == null) return;
    await signedIn(current.identity);
  }

  Future<void> _open(Identity identity, int epoch) async {
    final cacheKey = 'medipop_package_${identity.key}';
    final prefs = await SharedPreferences.getInstance();
    ClinicalPackage package;
    var fromCache = false;
    try {
      package = await adapters.config.load(identity);
      await prefs.setString(cacheKey, package.encode());
    } on OfflineException {
      final cached = prefs.getString(cacheKey);
      if (cached == null) {
        throw StateError('First configuration requires Internet.');
      }
      package = ClinicalPackage.parse(cached);
      fromCache = true;
    }
    if (epoch != _epoch) return;
    workspace = Workspace(identity, package);
    offline = fromCache;
    error = null;
  }

  /// Validates before replacing, so an invalid file never disables the
  /// active package.
  Future<void> importPackage(String source) async {
    final current = workspace;
    if (current == null || !adapters.config.allowsLocalImport) {
      throw StateError('Packages are managed by your organization.');
    }
    final parsed = ClinicalPackage.parse(source);
    await adapters.config.importPackage(current.identity, parsed);
    if (workspace?.key != current.key) return;
    workspace = Workspace(current.identity, parsed);
    notifyListeners();
  }

  Future<void> signOut() async {
    final identity = workspace?.identity;
    _close();
    if (identity != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('medipop_package_${identity.key}');
    }
    await _identity.signOut();
  }

  void _close() {
    _epoch++;
    workspace = null;
    loading = false;
    offline = false;
    notifyListeners();
  }

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  @override
  void dispose() {
    _signedOut?.cancel();
    super.dispose();
  }
}
