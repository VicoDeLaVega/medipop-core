## Context

Le client démarre sur HomeScreen. PrescriptionDraft, ReviewScreen et le prompt sont spécialisés. SyncService utilise insert sans identité stable transmise. Le SQL local autorise anon/authenticated en lecture et insertion sans restriction. Qwen 2.5 1.5B est déclaré comme asset; le téléchargement lève une erreur. Le README décrit encore fllama alors que le code utilise llamadart.

## Goals / Non-Goals

**Goals:** garder une seule app et préserver les données locales; séparer identité serveur, package métier et modèle.

**Non-Goals:** inventer les champs cliniques APTITUD, publier le code, déployer Supabase, ajouter SSO/MFA, choisir une licence ou promettre une transcription entièrement offline. macOS/Windows nécessiteront une évolution séparée: seules les plateformes iOS/Android existent actuellement.

## Decisions

1. Package JSON versionné avec manifest, schéma de formulaire et prompt. Support initial explicite: texte, nombre, booléen, choix, groupes et listes. Rejeter les types inconnus; ne pas accepter du code exécutable. L'exemple public reproduit les ordonnances actuelles. APTITUD reste un squelette tant que ses champs ne sont pas fournis.
2. Une enveloppe de consultation générique contient UUID stable, organization_id, created_by_user_id, device_id, schema_id, schema_version et payload. Préserver le format ancien via adaptateur plutôt que réécrire silencieusement toutes les lignes.
3. Supabase Auth email/mot de passe et table membership contrôlée côté serveur. Ni rôle ni organisation venant du client ne font autorité. Doctor saisit/valide; admin consulte/exporte au sein de son organisation. Chaque requête du dashboard utilise une session utilisateur, sans clé privilégiée.
4. Le premier login et le premier chargement de configuration nécessitent le réseau. Ensuite une identité et une configuration déjà connues permettent le travail local. Partitionner le stockage par compte et organisation; déconnexion masque les données, changement de compte ne réattribue jamais la file de synchronisation. Une session expirée suspend la sync, une révocation est appliquée dès qu'elle est connue.
5. Modèle dans le répertoire de support de l'app: import ou HTTPS vers fichier temporaire, SHA-256 obligatoire avant activation, renommage atomique. Conserver le dernier modèle valide en cas d'échec. Pas de valeur de hash inventée. Conserver llamadart et le modèle actuel pour limiter les changements simultanés.
6. Pas de fork du moteur pour APTITUD: package compagnon indépendant. Les options de configuration seront documentées quand le chargeur sera implémenté; le squelette n'est pas présenté comme exécutable.

## Risks / Trade-offs

- Données historiques sans organisation → attribution explicite et sauvegarde; aucune affectation automatique.
- Retry de sync après réponse perdue → UUID source et upsert soumis aux mêmes contrôles d'accès; test de doublon.
- Perte réseau pendant installation → fichier partiel jamais activé, reprise utilisateur.
- Révocation non détectable offline → pas de sync avant nouvelle vérification serveur.
- Accès prototype permissifs → valider une migration RLS sur base de test avant déploiement coordonné client/admin.

## Migration Plan

Sauvegarder la base; introduire structures génériques et adaptateur local; tester auth/RLS avec deux organisations; attribuer explicitement les données anciennes; déployer clients et dashboard compatibles avant retrait des accès anonymes. En cas d'échec, suspendre la sync et préserver les files locales, sans rétablir les politiques publiques. Aucun déploiement dans cette étape de préparation.

## Précisions d’implémentation

- Le stockage local v3 utilise des fichiers SQLite distincts par empreinte compte/organisation; la base historique est conservée et attribuée explicitement par un administrateur.
- La synchronisation utilise une RPC transactionnelle idempotente avec enregistrements validés immuables; une réutilisation d’UUID avec un contenu différent est refusée.
- Le dashboard utilise des cookies HttpOnly et vérifie le jeton utilisateur sur le serveur. À expiration, une nouvelle connexion est requise. Next.js passe à 16.3.8 suite à l’audit des dépendances.
- L’exemple référence l’empreinte calculée du GGUF déjà présent localement, sans inclure ses octets dans le build.
