import 'package:flutter/foundation.dart';

/// One developmental age range a child can belong to, such as `12-23 months`.
@immutable
class AgeBand {
  /// Creates an [AgeBand] covering [minMonths] through [maxMonths].
  const AgeBand({
    required this.code,
    required this.label,
    required this.minMonths,
    required this.maxMonths,
  });

  /// API wire code for this band (for example, `12-23m`).
  final String code;

  /// Caregiver-facing label for this band (for example, `12-23 months`).
  final String label;

  /// Youngest supported age in this band, in months.
  final int minMonths;

  /// Oldest supported age in this band, in months.
  final int maxMonths;
}

/// Supported developmental age bands ordered from youngest to oldest.
const List<AgeBand> ageBands = [
  AgeBand(code: '0-5m', label: '0-5 months', minMonths: 0, maxMonths: 5),
  AgeBand(code: '6-11m', label: '6-11 months', minMonths: 6, maxMonths: 11),
  AgeBand(code: '12-23m', label: '12-23 months', minMonths: 12, maxMonths: 23),
  AgeBand(code: '24-35m', label: '24-35 months', minMonths: 24, maxMonths: 35),
  AgeBand(code: '36-47m', label: '36-47 months', minMonths: 36, maxMonths: 47),
  AgeBand(code: '48-59m', label: '48-59 months', minMonths: 48, maxMonths: 59),
  AgeBand(code: '60-71m', label: '60-71 months', minMonths: 60, maxMonths: 71),
];

/// Returns whole months elapsed between [birthYear]/[birthMonth] and [now].
int ageInMonths({
  required int birthYear,
  required int birthMonth,
  required DateTime now,
}) {
  return (now.year * 12 + now.month) - (birthYear * 12 + birthMonth);
}

/// Returns the [AgeBand] containing [months], or `null` if outside `0-71`.
AgeBand? ageBandForMonths(int months) {
  for (final band in ageBands) {
    if (months >= band.minMonths && months <= band.maxMonths) {
      return band;
    }
  }
  return null;
}

/// Returns the [AgeBand] matching API [code], or `null` if unrecognized.
AgeBand? ageBandForCode(String code) {
  for (final band in ageBands) {
    if (band.code == code) {
      return band;
    }
  }
  return null;
}
