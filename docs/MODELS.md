# Modèle externe

Les GGUF ne sont pas inclus dans l’application : chaque organisme choisit son modèle dans son package (`model.sha256`, `model.url`).

Le moteur est agnostique du modèle : le prompt est rendu avec le chat template embarqué dans le GGUF (Qwen, Gemma, Llama, Mistral…), le mode « thinking » est désactivé et tout bloc `<think>` résiduel est retiré avant l’analyse JSON. Chaque package choisit son modèle via `model.sha256`.

Empreintes SHA-256 calculées sur les fichiers locaux (pas une attestation du fournisseur) :

| Fichier | SHA-256 |
|---|---|
| `Qwen3-1.7B-Q4_K_M.gguf` (attendu par l’exemple public; source : `unsloth/Qwen3-1.7B-GGUF` sur Hugging Face) | `b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897` |
| `qwen2.5-1.5b-instruct-q4_k_m.gguf` (ancien prototype) | `6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e` |

L’installation se fait depuis **Install AI model → Import local GGUF**. Les fichiers GGUF ne sont jamais versionnés.
