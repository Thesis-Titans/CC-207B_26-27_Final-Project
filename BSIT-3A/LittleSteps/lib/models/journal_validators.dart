/// The longest journal note the API accepts.
const int maxJournalLength = 2000;

// Matches invisible control characters (except line breaks and tabs) and
// invisible Unicode format characters such as zero-width spaces.
final RegExp _forbiddenCharacters = RegExp(
  r'[^\P{Cc}\r\n\t]|\p{Cf}',
  unicode: true,
);

/// Returns an error message if [value] is not a valid journal note,
/// or null if it is valid.
///
/// Line breaks are allowed in notes, unlike nicknames. The length counts
/// the note as typed, the same way the API and the form's counter do.
String? validateJournalContent(String? value) {
  final content = value ?? '';

  if (content.trim().isEmpty) {
    return 'Write a note';
  }
  if (content.length > maxJournalLength) {
    // The API's own wording for the 2,000-character limit.
    return 'Notes can be up to 2,000 characters. '
        'Please make this one a little shorter.';
  }
  if (_forbiddenCharacters.hasMatch(content)) {
    return 'Remove hidden characters from the note';
  }
  return null;
}

/// Returns an error message if [date] is after the day of [now],
/// or null if it is valid.
///
/// Only the day is compared, so any time later today still counts as
/// today.
String? validateEntryDate(DateTime date, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);

  if (day.isAfter(today)) {
    return "The date can't be in the future";
  }
  return null;
}
