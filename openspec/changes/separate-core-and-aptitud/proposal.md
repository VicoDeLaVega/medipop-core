## Why

Le prototype Medipop sait dicter et synchroniser des ordonnances, mais les champs, le prompt et le modèle sont liés au build. La séparation proposée permet de réutiliser le même client avec un package métier APTITUD privé.

## What Changes

- Charger un package métier versionné et conserver un exemple public fictif.
- Ajouter connexion email/mot de passe, appartenance à une organisation et rôles doctor/admin.
- **BREAKING** Supprimer les politiques SQL anonymes du prototype et isoler les enregistrements par organisation.
- Sortir le GGUF du bundle et permettre import local ou téléchargement vérifié.
- Migrer progressivement les ordonnances existantes sans perte de données.
- Adapter aussi le dashboard à l'authentification et à l'isolation.

## Capabilities

### New Capabilities
- `organization-packages`: configuration versionnée, formulaires et extraction pilotés par données.
- `organization-auth`: identité, organisation, isolation et synchronisation attribuée.
- `external-models`: installation indépendante du modèle local.

### Modified Capabilities
Aucune spécification existante trouvée dans Medipop.

## Impact

Flutter: lib/app.dart, lib/config/, lib/services/, lib/data/, lib/ui/, pubspec.yaml.
Supabase: migrations additionnelles, adhésions, politiques RLS.
Admin: authentification serveur et requêtes avec session utilisateur.
Package compagnon: ../medipop-aptitud, sans dépendance inverse du Core.
Cette proposition ne publie aucun dépôt et ne modifie aucun service distant.
