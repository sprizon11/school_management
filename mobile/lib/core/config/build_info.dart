/// Identifies which build is actually running.
///
/// Sideloaded iOS installs replace silently and offer no version UI, so
/// without this there's no way to tell a fresh build from a stale one on the
/// device. CI passes the real commit; local builds fall back to "dev".
class BuildInfo {
  /// Keep in step with `version:` in pubspec.yaml.
  static const version = '1.0.2';

  /// Short commit hash, injected by CI via --dart-define=BUILD_COMMIT.
  static const commit = String.fromEnvironment(
    'BUILD_COMMIT',
    defaultValue: 'dev',
  );

  /// e.g. "v1.0.2 · a7abc64" — what the More screen shows.
  static String get label =>
      commit == 'dev' ? 'v$version · local' : 'v$version · $commit';
}
