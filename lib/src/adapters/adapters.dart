import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';

import '../data/consultation.dart';
import '../package/clinical_package.dart';

/// Who is working, for which organization. Roles are opaque to the core:
/// adapters and servers decide what they allow.
class Identity {
  const Identity(
      {required this.userId, required this.organizationId, required this.role});
  final String userId, organizationId, role;

  /// Scopes local storage and the outbox; never shared across accounts.
  String get key =>
      sha256.convert(utf8.encode('$userId/$organizationId')).toString();

  Map<String, dynamic> toJson() =>
      {'userId': userId, 'organizationId': organizationId, 'role': role};
  factory Identity.fromJson(Map<String, dynamic> j) => Identity(
      userId: j['userId'] as String,
      organizationId: j['organizationId'] as String,
      role: j['role'] as String);
}

/// Thrown by adapters when the network is unavailable, so the core can fall
/// back to the last known configuration instead of locking the user out.
class OfflineException implements Exception {
  const OfflineException([this.message = 'Offline']);
  final String message;
  @override
  String toString() => message;
}

/// Authentication and organization membership. Implementations live outside
/// the core (OIDC, Supabase…) because identity rules differ per country.
abstract class IdentityProvider {
  /// False for providers that never show a sign-in screen.
  bool get requiresSignIn;

  /// Returns the known identity, possibly offline, or null if sign-in is needed.
  Future<Identity?> restore();

  /// Interactive sign-in. Must call [onSignedIn] once an organization is chosen.
  Widget buildSignIn(
      BuildContext context, Future<void> Function(Identity) onSignedIn);

  /// Online re-check before sending data. Returning false suspends sync.
  Future<bool> authorize(Identity identity);

  /// Emits when the provider ends the session (expiry, revocation, remote sign-out).
  Stream<void> get signedOut;

  Future<void> signOut();
}

/// Where the active clinical package comes from.
abstract class ConfigSource {
  /// May throw [OfflineException]; the core then uses its cached copy.
  Future<ClinicalPackage> load(Identity identity);

  /// Whether a user may activate a package file on the device.
  bool get allowsLocalImport => false;

  /// Persists an already validated package for [identity].
  Future<void> importPackage(Identity identity, ClinicalPackage package) =>
      throw UnsupportedError('Packages are managed by your organization.');
}

/// Destination of validated consultations. Sending the same record twice
/// must be harmless: the record UUID is the idempotency key.
abstract class SyncTarget {
  bool get enabled;
  Future<void> send(Consultation record, Identity identity);
}

/// Everything an organization chooses; assembled by the app shell.
class MedipopAdapters {
  const MedipopAdapters(
      {required this.identity, required this.config, required this.sync});
  final IdentityProvider identity;
  final ConfigSource config;
  final SyncTarget sync;
}
