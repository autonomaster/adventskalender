import 'package:flutter/foundation.dart';

/// "Today" for the calendar: the device clock, or a test date while one is
/// set (Supabase `app_config.test_date`, or `ADVENT_DEMO_TODAY` in demo mode).
/// Notifies listeners when the test date changes.
class CalendarClock extends ChangeNotifier {
  CalendarClock({
    DateTime Function()? system,
    Future<DateTime?> Function()? loadTestDate,
    DateTime? testDate,
  }) : _system = system ?? DateTime.now,
       _loadTestDate = loadTestDate,
       _testDate = testDate;

  final DateTime Function() _system;
  final Future<DateTime?> Function()? _loadTestDate;
  DateTime? _testDate;
  Future<void>? _refreshing;

  DateTime? get testDate => _testDate;

  /// The test date at the device's current time of day, or the device time.
  DateTime now() {
    final time = _system();
    final date = _testDate;
    if (date == null) {
      return time;
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
      time.second,
    );
  }

  /// Reloads the test date. Concurrent calls share one request.
  Future<void> refresh() {
    final load = _loadTestDate;
    if (load == null) {
      return Future.value();
    }
    return _refreshing ??= () async {
      try {
        final date = await load();
        if (date != _testDate) {
          _testDate = date;
          notifyListeners();
        }
      } finally {
        _refreshing = null;
      }
    }();
  }
}
