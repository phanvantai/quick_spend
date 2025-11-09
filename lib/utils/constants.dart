/// Application-wide constants
class AppConstants {
  /// Default user ID for local storage
  ///
  /// Since this is a local-only app (no cloud sync), we use a single
  /// consistent user ID for all expenses stored locally.
  static const String defaultUserId = 'local_user';

  // Private constructor to prevent instantiation
  AppConstants._();
}
