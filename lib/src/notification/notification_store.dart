import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for which in-app notifications have been read.
///
/// The notifications themselves are still static reference content
/// (see data/mock_data.dart) — only the read/unread state is stored here,
/// keyed by notification id, so "tandai dibaca" survives navigation and app
/// restarts. Replace with a backend endpoint when notifications get a
/// repository.
class NotificationStore {
  static const _key = 'read_notification_ids';

  /// Ids the user has already marked as read.
  static Future<Set<String>> readIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  /// Mark the given notification ids as read (merged with what's already saved).
  static Future<void> markRead(Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_key) ?? const <String>[]).toSet()
      ..addAll(ids);
    await prefs.setStringList(_key, current.toList());
  }
}
