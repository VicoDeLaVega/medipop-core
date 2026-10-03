import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/consultation.dart';
import '../package/clinical_package.dart';
import 'adapters.dart';

const examplePackageAsset =
    'packages/medipop_core/assets/packages/example-prescription.json';

/// One user per device, no account, no network. Suited to a clinic that only
/// needs offline capture and export.
class LocalIdentity implements IdentityProvider {
  LocalIdentity({this.organizationId = 'local', this.role = 'clinician'});
  final String organizationId, role;

  @override
  bool get requiresSignIn => false;

  @override
  Future<Identity> restore() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('medipop_local_user');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('medipop_local_user', id);
    }
    return Identity(userId: id, organizationId: organizationId, role: role);
  }

  @override
  Widget buildSignIn(BuildContext context, onSignedIn) =>
      throw UnsupportedError('Local identity has no sign-in.');

  @override
  Future<bool> authorize(Identity identity) async => true;

  @override
  Stream<void> get signedOut => const Stream.empty();

  @override
  Future<void> signOut() async {}
}

/// A package shipped with the app, optionally replaced by a file the user
/// imports. Imported packages persist per identity.
class BundledConfigSource extends ConfigSource {
  BundledConfigSource(
      {this.asset = examplePackageAsset, this.allowImport = true});
  final String asset;
  final bool allowImport;

  @override
  bool get allowsLocalImport => allowImport;

  @override
  Future<ClinicalPackage> load(Identity identity) async {
    if (allowImport) {
      final prefs = await SharedPreferences.getInstance();
      final imported = prefs.getString('medipop_imported_${identity.key}');
      if (imported != null) return ClinicalPackage.parse(imported);
    }
    return ClinicalPackage.parse(await rootBundle.loadString(asset));
  }

  @override
  Future<void> importPackage(Identity identity, ClinicalPackage package) async {
    if (!allowImport) return super.importPackage(identity, package);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'medipop_imported_${identity.key}', package.encode());
  }
}

/// Records stay on the device; use export to hand them over.
class NoSync implements SyncTarget {
  const NoSync();
  @override
  bool get enabled => false;
  @override
  Future<void> send(Consultation record, Identity identity) =>
      throw UnsupportedError('Synchronization is disabled.');
}

/// Standalone setup: no account, bundled package, no server.
MedipopAdapters localAdapters() => MedipopAdapters(
    identity: LocalIdentity(),
    config: BundledConfigSource(),
    sync: const NoSync());
