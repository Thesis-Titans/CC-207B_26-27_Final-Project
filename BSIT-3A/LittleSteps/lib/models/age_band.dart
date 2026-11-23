/// One age range a child can belong to, such as 12-23 months.
class AgeBand {
  /// Creates an age band covering [minMonths] to [maxMonths].
  const AgeBand({
    required this.code,
    required this.label,
    required this.minMonths,
    required this.maxMonths,
  });

  /// The value the API expects, such as '12-23m'.
  final String code;

  /// The text caregivers see, such as '12-23 months'.
  final String label;

  /// The youngest age in this band, in months.
  final int minMonths;

  /// The oldest age in this band, in months.
  final int maxMonths;
}

/// Every age band the API accepts, youngest first.
/// The age bands are defined with their
/// respective codes, labels, and minimum and maximum months.
const List<AgeBand> ageBands = [
  AgeBand(code: '0-5m', label: '0-5 months', minMonths: 0, maxMonths: 5),
  AgeBand(code: '6-11m', label: '6-11 months', minMonths: 6, maxMonths: 11),
  AgeBand(code: '12-23m', label: '12-23 months', minMonths: 12, maxMonths: 23),
  AgeBand(code: '24-35m', label: '24-35 months', minMonths: 24, maxMonths: 35),
  AgeBand(code: '36-47m', label: '36-47 months', minMonths: 36, maxMonths: 47),
  AgeBand(code: '48-59m', label: '48-59 months', minMonths: 48, maxMonths: 59),
  AgeBand(code: '60-71m', label: '60-71 months', minMonths: 60, maxMonths: 71),
];

/// Returns how many whole months old a child born in
/// [birthYear]/[birthMonth] is on [now].
int ageInMonths({
  required int birthYear,
  required int birthMonth,
  required DateTime now,
}) {
  // Count total months for each date, then subtract.
  return (now.year * 12 + now.month) - (birthYear * 12 + birthMonth);
}

/// Returns the band that [months] falls in, or null if it is
/// outside 0-71 (too young/future date, or too old).
AgeBand? ageBandForMonths(int months) {
  for (final band in ageBands) {
    if (months >= band.minMonths && months <= band.maxMonths) {
      return band;
    }
  }
  return null;
}
