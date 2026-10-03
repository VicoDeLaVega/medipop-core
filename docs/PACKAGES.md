# Contrat des packages, version 1

Un package est un seul fichier JSON déclaratif:

```json
{
  "formatVersion": 1,
  "id": "example-intake",
  "version": "1.0.0",
  "title": "Example intake",
  "locale": "en_US",
  "prompt": "Extract only dictated facts for {{SCHEMA}}. Return JSON. Dictation: {{TRANSCRIPT}}",
  "fields": [
    { "id": "note", "label": "Note", "type": "text", "required": true },
    { "id": "score", "label": "Score", "type": "number" },
    { "id": "confirmed", "label": "Confirmed", "type": "boolean" },
    { "id": "category", "label": "Category", "type": "choice", "options": ["A", "B"] }
  ]
}
```

`group` et `list` contiennent une liste `fields` de même format. Un groupe devient un objet JSON; une liste devient un tableau d'objets. Les identifiants doivent être uniques dans leur groupe, commencer par une lettre et ne contenir que lettres ASCII, chiffres ou `_`. La profondeur est limitée à 8 et chaque liste de champs à 100. Les valeurs absentes restent nulles, sauf les listes vides. Les champs requis sont vérifiés à la validation humaine. Une valeur numérique invalide ou un choix inconnu n'est pas accepté comme valeur valide.

## Langues

`locales` liste les langues de dictée proposées, la première étant celle par défaut (codes `fr_FR`, `en_US`, `es_CL`…). L'ancien champ `locale` reste accepté. Avec plusieurs langues, l'écran de dictée affiche un sélecteur et retient le dernier choix.

`label` accepte une chaîne ou un objet par langue, par exemple `{"fr": "Posologie", "en": "Posology"}`. Les libellés suivent la langue de l'appareil, avec repli sur l'anglais.

## Identité visuelle

`branding` est facultatif : `name` (nom affiché), `primaryColor` (`#RRGGBB`, couleur principale de l'interface) et `logoUrl` (HTTPS). L'app les applique après la connexion ; sans réseau, le logo est simplement masqué.

## Prompt

Les deux placeholders du prompt sont obligatoires. `{{LANGUAGE}}` est facultatif et reçoit la langue de dictée choisie. `{{SCHEMA}}` reçoit les définitions de champs et `{{TRANSCRIPT}}` la dictée. La sortie reste un brouillon à relire. Un JSON de modèle malformé ouvre un formulaire vide avec avertissement, sans inventer de données.

Un bloc optionnel `model` accepte `sha256` (64 caractères hexadécimaux) et `url` (HTTPS directe). Fournir une empreinte réelle. Quand le package impose une empreinte, un autre modèle n'est pas utilisé pour l'extraction.

## Activation

En mode autonome, **Load a package JSON** permet d'importer un fichier via le sélecteur système. Dans une organisation, l'administrateur de déploiement renseigne `organizations.package` côté serveur. Une valeur SQL NULL sélectionne l'exemple public. Le compte mobile peut rafraîchir sa configuration depuis l'accueil; un package invalide n'écrase pas la configuration valide déjà active.

Pour un changement métier, incrémenter `version`. Chaque consultation conserve `schema_id`, `schema_version` et `schema_snapshot`, donc les anciens enregistrements ne sont pas réinterprétés avec un nouveau formulaire.

## APTITUD

Le dossier compagnon `medipop-aptitud` contiendra le formulaire approuvé, les vocabulaires et les mappings. Le charger ne nécessite pas de modifier le Core. Aucun champ clinique ou mapping d'export APTITUD n'est présumé à partir de l'exemple fictif.
