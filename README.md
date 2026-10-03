# medipop-core

Offline clinical dictation for any healthcare organization. A clinician dictates, a **local LLM** fills a structured form defined by a **declarative JSON package**, the clinician **reviews and validates**, and the record is stored on the device. No account, server or Internet connection is required.

> Medipop is a data-entry tool with mandatory human validation. It is not a diagnostic aid and makes no clinical decision.

## What the core does

- Speech-to-text through the platform recognizer, in the package's language.
- Extraction with any instruct GGUF model run on-device via [`llamadart`](https://pub.dev/packages/llamadart). The prompt goes through the model's own chat template, so Qwen, Gemma, Llama or Mistral work without code changes.
- Forms, prompt, language and model pin come from a versioned package (`text`, `number`, `boolean`, `choice`, `group`, `list`). See [docs/PACKAGES.md](docs/PACKAGES.md).
- Models are installed separately (file import or HTTPS) and verified by SHA-256 before use. See [docs/MODELS.md](docs/MODELS.md).
- Validated records are stored in SQLite, one database per identity, and exported as JSON through the system share sheet.

## What the core does not do

Identity, organization configuration and synchronization depend on each country's rules. The core only defines interfaces:

| Interface | Role | Default |
|---|---|---|
| `IdentityProvider` | Who is working, for which organization | `LocalIdentity` (one user per device) |
| `ConfigSource` | Which package is active | `BundledConfigSource` (bundled example, user-importable) |
| `SyncTarget` | Where validated records go | `NoSync` (local only, export) |

Ready-made adapters (OIDC, Supabase, webhook…) live in `medipop-connectors`. An organization composes the core and its adapters in its own app shell:

```dart
import 'package:medipop_core/medipop_core.dart';

void main() => runMedipop(MedipopAdapters(
      identity: MyIdentityProvider(),
      config: MyConfigSource(),
      sync: MySyncTarget(),
    ));
```

## Run the standalone example

```sh
cd example
flutter create --platforms=ios,android .
flutter run
```

On iOS, every app shell needs:

- `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` in `ios/Runner/Info.plist`;
- in the `ios/Podfile` `post_install` block, `PERMISSION_MICROPHONE=1` and `PERMISSION_SPEECH_RECOGNIZER=1` added to `GCC_PREPROCESSOR_DEFINITIONS` — otherwise `permission_handler` reports the microphone as permanently denied without prompting;
- with Xcode 27 and Flutter 3.41, `IPHONEOS_DEPLOYMENT_TARGET = 15.0` for all pods and `EXCLUDED_ARCHS[sdk=iphonesimulator*] = i386 x86_64`.

See the `medipop-aptitud` app shell for a working `Podfile`.

## Verify

```sh
flutter pub get
flutter analyze
flutter test
dart --packages=.dart_tool/package_config.json tool/verify_core.dart
```

## Health data

Speech recognition may use the network depending on the device and language, and local storage is not yet encrypted. On-device-only speech and encrypted storage are planned as profile options (`openspec/changes/split-core-adapters-profiles`). Each organization remains responsible for compliance with its applicable law (HDS, GDPR, HIPAA…).

## License

MIT. See [LICENSE](LICENSE).
