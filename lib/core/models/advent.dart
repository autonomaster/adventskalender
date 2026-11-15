/// Calendar rules for the advent season: doors 1-24 in December.
const int adventDoorCount = 24;

/// Door positions on the calendar grid, shuffled like a paper calendar.
const List<int> adventDoorLayout = [
  7, 15, 2, 21, //
  12, 1, 18, 9,
  24, 5, 14, 20,
  3, 11, 23, 8,
  17, 6, 19, 13,
  10, 22, 4, 16,
];

DateTime dateOnly(DateTime time) => DateTime(time.year, time.month, time.day);

/// The December the calendar shows. Until the end of June the previous
/// December stays visible, afterwards the upcoming one.
int adventSeasonYear(DateTime today) =>
    today.month >= 7 ? today.year : today.year - 1;

DateTime adventDate(int year, int door) {
  if (door < 1 || door > adventDoorCount) {
    throw RangeError.range(door, 1, adventDoorCount, 'door');
  }
  return DateTime(year, 12, door);
}

/// A door opens at local midnight of its day.
bool isDoorUnlocked(DateTime day, DateTime now) =>
    !dateOnly(now).isBefore(dateOnly(day));

String formatAdventDay(DateTime day) => '${day.day} December ${day.year}';
