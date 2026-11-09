/// App-wide constants that show up on screens (splash, login, drawer, PDF later).
class AppInfo {
  AppInfo._();

  static const name = 'Piggery Evaluator';
  static const tagline = "Farmer's Choice · Pig department";

  // Keep in step with `version:` in pubspec.yaml. Hardcoded rather than read
  // with package_info_plus: one less plugin for a string that changes a few
  // times a year.
  static const version = '0.1.0';
}