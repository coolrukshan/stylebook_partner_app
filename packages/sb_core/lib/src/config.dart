/// Build-time config. Override with `--dart-define=API_BASE_URL=https://...`.
abstract final class SbConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');
}
