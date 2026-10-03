## 1. Packages et compatibilité

- [x] 1.1 Implémenter validation et chargement des packages; vérifier package valide, version incompatible et type inconnu.
- [ ] 1.2 Extraire le formulaire/prompt ordonnance en exemple public fictif; vérifier le parcours existant et le démarrage sans APTITUD.
- [x] 1.3 Ajouter enveloppe générique et adaptateur legacy; vérifier migration sans perte et conservation de schema_version.

## 2. Identité et stockage

- [ ] 2.1 Ajouter login/logout email et restauration de session; vérifier premier lancement, erreur de connexion et session expirée.
- [ ] 2.2 Partitionner cache, données et sync par identité/organisation; vérifier déconnexion puis connexion d'un autre compte offline/online.
- [x] 2.3 Écrire migrations membership/RLS et attribution historique; vérifier deux organisations, rôles, accès anonyme et usurpation sur base de test.
- [x] 2.4 Rendre la sync idempotente avec UUID et identité; vérifier retry après réponse perdue, refus serveur et conservation de file.
- [x] 2.5 Ajouter auth au dashboard et appliquer les rôles côté serveur; vérifier accès direct aux routes et export non autorisé.

## 3. Modèle externe

- [x] 3.1 Ajouter import/téléchargement temporaire avec hash et activation atomique; vérifier interruption, mauvais hash et conservation du modèle précédent.
- [ ] 3.2 Retirer l'asset GGUF du build et ajouter l'écran d'installation; vérifier premier lancement, mise à jour et inférence offline sur appareil.

## 4. Vérification et documentation

- [ ] 4.1 Mettre README et SETUP à jour; vérifier les instructions sur environnement propre et préciser les limites offline du STT.
- [ ] 4.2 Exécuter analyse Flutter, tests ciblés et build admin; vérifier un parcours complet avec deux comptes et deux organisations.
- [ ] 4.3 Documenter sauvegarde, migration et retour arrière sans réouverture des accès publics; livrer une procédure de déploiement testée.

Le schéma clinique et les mappings Excel APTITUD feront l'objet d'une définition distincte à partir des documents métier fournis.

## État de livraison

Le code des autres items est implémenté et la documentation est rédigée. Les cases restent ouvertes lorsque leur critère inclut une exécution complète sur appareil, Supabase Auth réel ou une procédure de déploiement/restauration non effectuée. Voir `docs/VALIDATION.md` à la racine du projet pour distinguer tests réussis et vérifications restantes.
