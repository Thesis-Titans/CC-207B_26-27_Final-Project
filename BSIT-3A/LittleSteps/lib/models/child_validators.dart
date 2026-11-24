import 'age_band.dart';

/// The longest nickname the API accepts, after trimming spaces.
const int maxNicknameLength = 50;

/// Matches invisible control characters (such as tabs or line breaks),
/// which the API rejects in a nickname.
final RegExp _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

/// Matches a nickname made only of letters (any language), spaces,
/// hyphens, apostrophes and periods, such as "Mary-Ann" or "José".
///
/// This is stricter than the API, which also accepts numbers and symbols.
final RegExp _allowedNickname = RegExp(r"^[\p{L}\p{M} '.-]+$", unicode: true);

/// Returns an error message if [value] is not a valid nickname,
/// or null if it is valid.
///
/// Spaces at the start and end are ignored, so a nickname of only
/// spaces counts as empty.
String? validateNickname(String? value) {
  final nickname = (value ?? '').trim();

  if (nickname.isEmpty) {
    return 'Enter a nickname';
  }
  if (nickname.length > maxNicknameLength) {
    return 'Use $maxNicknameLength characters or fewer';
  }
  if (_controlCharacters.hasMatch(nickname)) {
    return "Nickname can't contain line breaks or tabs";
  }
  if (!_allowedNickname.hasMatch(nickname)) {
    return "Use letters only. Spaces, - and ' are fine.";
  }
  return null;
}

/// Returns an error message if a child born in [year]/[month] is
/// outside the supported age range on [now], or null if it is valid.
///
/// The oldest supported age comes from the last band in [ageBands],
/// so the two files always agree.
String? validateBirthMonthYear({
  required int year,
  required int month,
  required DateTime now,
}) {
  final months = ageInMonths(birthYear: year, birthMonth: month, now: now);
  final maxMonths = ageBands.last.maxMonths;

  if (months < 0) {
    return "Birth date can't be in the future";
  }
  if (months > maxMonths) {
    return 'Little Steps supports ages 0-$maxMonths months';
  }
  return null;
}
