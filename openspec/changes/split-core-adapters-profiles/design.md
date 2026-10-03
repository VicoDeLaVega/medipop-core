## Context

État après `separate-core-and-aptitud`: packages JSON de formulaire et prompt, modèle externe vérifié par SHA-256, extraction agnostique du modèle via le chat template du GGUF. Mais `SessionService` mélange Supabase Auth, adhésions et chargement du package depuis `organizations.package`; `SyncService` n'appelle que la RPC `submit_consultation`; sans Supabase seul un mode démo non persistant existe. Le STT plateforme peut envoyer l'audio aux serveurs d'Apple ou de Google, et SQLite n'est pas chiffré.

## Goals / Non-Goals

**Goals:** un core public utilisable seul par un hôpital; des adaptateurs remplaçables selon le pays; un organisme qui configure sans forker le core; un passage en HDS sans modifier le code du core.

**Non-Goals:** écrire un fournisseur d'identité; garantir une conformité légale (elle relève de chaque organisme et de son DPO); un dispositif médical d'aide au diagnostic; Whisper embarqué dans ce changement (prévu comme option ultérieure).

## Decisions

1. **Trois dépôts, dépendances à sens unique.** Le core ne connaît aucun adaptateur concret. Les adaptateurs dépendent du core. Le dépôt de profil compose les deux. Dépendances Dart via git tag, ou pub.dev plus tard.
2. **Interfaces du core:**
   - `IdentityProvider`: utilisateur courant, organisation, rôle, jeton pour la sync, déconnexion. Défaut `LocalIdentity` (un utilisateur de l'appareil, sans réseau).
   - `ConfigSource`: fournit le package actif et la version. Défauts: exemple embarqué, fichier importé.
   - `SyncTarget`: envoie une enveloppe de consultation de façon idempotente (UUID). Défauts: `NoSync`, `FileExport` (JSON/CSV).
   La logique d'outbox, de retry et d'isolation par espace de travail reste dans le core.
3. **Adaptateurs du dépôt 2:** `OidcIdentity` générique (authorization code + PKCE; couvre Pro Santé Connect, ClaveÚnica, Keycloak, Azure AD), `SupabaseIdentity`, `SupabaseConfigSource`, `SupabaseSync` (RPC actuelle), `WebhookSync` (POST HTTPS, en-tête d'idempotence, jeton de l'identité). Le dashboard Next.js et les migrations SQL vivent avec l'adaptateur Supabase.
4. **Profil déclaratif** `profile.json` dans le dépôt de l'organisme: `package`, `model` (sha256, url), `identity` (`local` | `oidc` | `supabase` + paramètres publics), `sync` (`none` | `export` | `supabase` | `webhook` + URL), `compliance` (`onDeviceSpeechOnly`, `encryptLocalDb`, `retentionDays`). Aucun secret. Les adaptateurs étant du code Dart compilé, chaque organisme livre sa coquille d'app (`main.dart` minimal) qui enregistre les adaptateurs autorisés; le profil sélectionne parmi eux.
5. **Conformité sur l'appareil, dans le core:** `onDeviceSpeechOnly` force la reconnaissance locale et refuse la dictée si elle est indisponible (la saisie manuelle reste possible). `encryptLocalDb` passe SQLite à SQLCipher, avec une clé dans le Keychain ou le Keystore. La conformité de l'hébergement se décide dans le profil, pas dans le code.
6. **Hébergement:** le serveur n'utilise que PostgreSQL standard (tables, RLS, fonctions). Passer de Supabase Cloud à Supabase auto-hébergé ou Postgres chez un hébergeur HDS revient à migrer la base et à changer l'URL du profil.
7. **Publication:** le dépôt public est créé avec un historique neuf, après revue des secrets, des URL de projet et des données. Licence MIT choisie par le propriétaire; README avec avertissement « outil de saisie avec validation humaine, pas une aide au diagnostic ».

## Pilotes

- **Pilote 1, données fictives (~10 utilisateurs):** Supabase Cloud (projet actuel, réinitialisé), auth Supabase, sync Supabase. Aucune donnée réelle ni identifiante, y compris en dictée de test.
- **Pilote 2, données réelles:** prérequis bloquants: hébergement certifié HDS (base, auth, dashboard, sauvegardes, logs); `onDeviceSpeechOnly` et `encryptLocalDb` activés; AIPD et validation par le DPO de l'organisme; procédure de sauvegarde et restauration testée. Auth envisagée: OIDC (Pro Santé Connect ou IdP de l'organisme) ou Supabase auto-hébergé.

## Risks / Trade-offs

- Fragmentation des versions entre dépôts → interfaces versionnées, suite de tests de contrat dans le core que chaque adaptateur exécute.
- STT local indisponible pour une langue ou un appareil → dictée refusée et saisie manuelle; Whisper local en évolution ultérieure.
- Perte de la clé de chiffrement locale → données locales illisibles; à documenter et à n'activer que si la sync est en place.
- Un organisme publie un profil incorrect → le profil est validé au démarrage, avec refus visible et conservation du dernier profil valide.
- MIT sans clause de brevets → Apache 2.0 reste possible; décision du propriétaire.

## Migration Plan

Travail local sur la branche `platform-core`: (1) introduire les interfaces et les implémentations par défaut dans le dépôt actuel, sans changer le comportement Supabase; (2) déplacer le code Supabase derrière les adaptateurs, avec les tests RLS inchangés; (3) ajouter profil, webhook et options de conformité; (4) préparer localement les trois dossiers de dépôts; (5) publication uniquement sur accord explicite.
