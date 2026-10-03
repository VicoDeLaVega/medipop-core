## Why

Medipop doit devenir une plateforme réutilisable par n'importe quel organisme de santé, pas une application APTITUD. Les règles d'authentification et d'hébergement des données de santé diffèrent selon les pays (HDS et Pro Santé Connect en France, loi 21.719 et ClaveÚnica au Chili…). Elles ne doivent donc pas vivre dans le moteur. Le changement `separate-core-and-aptitud` a séparé le package métier, mais l'auth, la configuration d'organisation et la synchronisation restent codées en dur sur Supabase, et le mode sans compte n'est qu'une démo.

## What Changes

- Découper le projet en trois dépôts aux dépendances à sens unique (3 → 2 → 1):
  1. `medipop-core`, public MIT: capture hors ligne (STT, LLM local, formulaire piloté par package, validation humaine, base locale, export) et interfaces `IdentityProvider`, `ConfigSource`, `SyncTarget`. Fonctionne seul.
  2. Adaptateurs publics: client OIDC générique, adaptateur Supabase (auth + sync), dashboard admin et migrations SQL. Réutiliser des systèmes d'identité existants plutôt qu'en écrire un.
  3. Dépôt de profil privé par organisme (`medipop-aptitud` en premier): package de données, modèle, choix d'auth et de sync, exigences de conformité, branding et coquille d'app.
- **BREAKING** Le mode démo devient un mode autonome de premier rang, avec base persistante et export.
- Ajouter un profil de déploiement déclaratif (`profile.json`) qui choisit adaptateurs et options de conformité.
- Ajouter une cible de sync webhook HTTPS générique en plus de Supabase.
- Ajouter dans le core des options de conformité côté appareil activées par profil: STT uniquement sur l'appareil, chiffrement SQLite.
- Planifier deux pilotes: pilote 1 en données fictives sur Supabase Cloud, pilote 2 en données réelles sur hébergement certifié HDS.

## Capabilities

### New Capabilities
- `standalone-capture`: capture, validation, stockage et export sans compte ni serveur.
- `pluggable-adapters`: identité, configuration et synchronisation derrière des interfaces stables.
- `deployment-profiles`: profil déclaratif par organisme, hors du dépôt public.
- `health-data-compliance`: options de conformité sur l'appareil et prérequis du pilote en données réelles.

### Modified Capabilities
- `organization-auth` (change `separate-core-and-aptitud`): devient l'adaptateur Supabase du dépôt 2 au lieu d'un composant du core.

## Impact

Flutter: extraction de `lib/` vers un package `medipop_core`; `session_service.dart` scindé entre identité et configuration; `sync_service.dart` derrière `SyncTarget`; `main.dart` réduit à une composition d'adaptateurs.
Supabase/admin: déplacés vers le dépôt d'adaptateurs sans changement de comportement; `tool/verify_rls.mjs` les accompagne.
APTITUD: reçoit profil et coquille d'app.
Publication: le dépôt public part d'un historique neuf, après revue des secrets. Aucun dépôt n'est créé ni publié sans accord explicite.
