# Environment Configuration (`env/`)

This directory contains JSON files used to define environment variables for different flavors of the application (e.g., development, staging, and production). 

These configuration files are injected into the Flutter application at compile/run time using the `--dart-define-from-file` flag.

## Files

- `dev.json`: Environment variables for the **development** flavor.
- `staging.json`: Environment variables for the **staging** flavor.
- `prod.json`: Environment variables for the **production** flavor.

## Keys

| Key | Type | Description |
| --- | --- | --- |
| `FLAVOR` | string | One of `dev`, `staging`, `prod`. Backs `EnvConfig.isDev/isStaging/isProd`. |
| `API_BASE_URL` | string | Base URL for the HTTP client. |
| `API_TIMEOUT_SECONDS` | int | Connect/receive timeout for Dio, in seconds. Defaults to 10 if omitted. |

## Usage

When running or building the app, specify the target environment file.

**Using Flutter CLI:**
```bash
fvm flutter run --dart-define-from-file=env/dev.json
fvm flutter build apk --dart-define-from-file=env/prod.json
```

**Using VS Code:**
The `.vscode/launch.json` file is already configured to use these environments. Simply select "Dev (Debug)", "Staging (Debug)", or "Prod (Release)" from the Run/Debug panel in VS Code.

## Reading Values in Dart

Inside the application, these variables are mapped to strongly-typed properties through the `EnvConfig` class using `String.fromEnvironment`. 

```dart
// Example of how it's defined in packages/config/lib/src/env_config.dart
String get apiBaseUrl => const String.fromEnvironment(
  'API_BASE_URL', 
  defaultValue: 'http://localhost:8080'
);
```

You can access these values anywhere in the application by injecting or locating `EnvConfig`:
```dart
final baseUrl = getIt<EnvConfig>().apiBaseUrl;
```

## Firebase Configuration Note

In this project, Firebase configuration is intentionally **not** managed within these `env/*.json` files. 

Instead, Firebase is configured natively via the FlutterFire CLI, which generates the `lib/firebase_options.dart` file and the native iOS/Android config files automatically. If you need to manage multiple Firebase environments, you should use the FlutterFire CLI to generate flavor-specific options files and switch them programmatically in `main.dart`.
