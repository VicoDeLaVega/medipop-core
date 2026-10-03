## 1. Interfaces du core (dépôt actuel, sans changement de comportement)

- [ ] 1.1 Définir `IdentityProvider`, `ConfigSource`, `SyncTarget`, et une suite de tests de contrat réutilisable par les adaptateurs.
- [x] 1.2 Implémenter `LocalIdentity`, `BundledConfigSource` (avec import persistant), `NoSync` et l'export JSON (partage système). CSV non fait.
- [x] 1.3 Remplacer le mode démo par un mode autonome persistant; vérifier capture → validation → historique → export sans réseau ni Supabase.

## 2. Adaptateurs

- [x] 2.1 Scinder `SessionService` en `SupabaseIdentity` et `SupabaseConfigSource`; `SyncService` utilise `SupabaseSync`. `verify_core.dart` et `verify_rls.mjs` passent sans modification fonctionnelle.
- [ ] 2.2 Ajouter `WebhookSync` (HTTPS, idempotence par UUID, jeton d'identité); tester le retry après réponse perdue contre un serveur local.
- [ ] 2.3 Ajouter `OidcIdentity` générique (code + PKCE); tester contre un Keycloak local.

## 3. Profils et conformité

- [ ] 3.1 Définir et valider `profile.json`; documenter dans `docs/PROFILES.md`; profils d'exemple: hôpital autonome, Supabase, OIDC + webhook.
- [ ] 3.2 Implémenter `onDeviceSpeechOnly` (refus de dictée si indisponible) et `encryptLocalDb` (SQLCipher + Keychain/Keystore), avec migration d'une base existante.
- [ ] 3.3 Réduire `main.dart` à une composition d'adaptateurs; créer la coquille APTITUD dans `medipop-aptitud`.

## 4. Pilote 1 (données fictives)

- [ ] 4.1 Réinitialiser le projet Supabase actuel, appliquer migration et seed, vérifier l'isolation de deux organisations dans l'app et le dashboard.
- [ ] 4.2 Build iPad/iPhone (licence Xcode à accepter), inférence Qwen3 sur appareil, parcours complet avec 2 comptes.

## 5. Découpage des dépôts

- [ ] 5.1 Préparer localement `medipop-core` avec un historique neuf, revue des secrets, licence MIT et avertissement médical.
- [ ] 5.2 Préparer localement le dépôt d'adaptateurs (Supabase, OIDC, webhook, admin, migrations).
- [ ] 5.3 Publication GitHub sur accord explicite uniquement.

## 6. Pilote 2 (données réelles), prérequis bloquants

- [ ] 6.1 Hébergement certifié HDS: base, auth, dashboard, sauvegardes, logs. Migration testée depuis le pilote 1.
- [ ] 6.2 `onDeviceSpeechOnly` et `encryptLocalDb` activés dans le profil APTITUD et vérifiés sur appareil.
- [ ] 6.3 AIPD et validation DPO de l'organisme; procédure de sauvegarde et restauration exécutée.

## État

1.1 : interfaces livrées et testées avec de faux adaptateurs dans `packages/medipop_core/test/core_test.dart`; la suite de contrat réutilisable par les adaptateurs reste à extraire. 1.3 et 2.1 sont vérifiés par `flutter test`, `verify_core.dart` et `dart analyze`, pas encore sur appareil.

## 7. Configuration par l'organisme (ajout du 2026-10-03)

- [x] 7.1 Packages multilingues: `locales`, sélecteur de langue de dictée, `{{LANGUAGE}}`, libellés par langue.
- [x] 7.2 `branding` (nom, couleur, logo HTTPS) appliqué après connexion.
- [x] 7.3 Carte d'installation du modèle sur l'accueil; téléchargement HTTPS avec redirections, SHA-256 vérifié une fois par session.
- [x] 7.4 medipop-connectors: `organization_packages` + RPC `publish_package` (admin uniquement), page dashboard « Configuration ». Nouvelle version appliquée au prochain lancement.
- [ ] 7.5 Téléchargement automatique du modèle en Wi-Fi, en arrière-plan avec reprise.
- [ ] 7.6 Traduction de l'interface du core (FR/EN).

## 8. App générique publiée (proposition du 2026-10-03)

- [ ] 8.1 Une app « Medipop » unique (TestFlight puis stores) contenant tous les adaptateurs; premier lancement: mode autonome ou « Se connecter à mon organisme » par QR code / lien.
- [ ] 8.2 QR code d'organisation: paramètres publics uniquement (URL du serveur, clé publishable, type d'identité); généré depuis le dashboard.
- [ ] 8.3 Les dépôts d'organisme ne contiennent plus que la configuration, sauf besoin d'une app à leur marque sur les stores.
