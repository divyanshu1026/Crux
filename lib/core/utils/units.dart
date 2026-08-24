/// Display-unit helpers. All weight data in Crux is stored in **kg**; these
/// convert to the user's chosen display unit at the presentation layer only.
library;

const double _kgPerLb = 0.45359237;

/// Formats a kg value for display in the user's [units] ('kg' or 'lbs').
///
/// Returns just the number (no unit suffix) so callers can lay out the unit
/// label separately in the mono/display type where needed.
String formatWeightValue(double kg, String units, {int decimals = 1}) {
  final value = units == 'lbs' ? kg / _kgPerLb : kg;
  // Drop a trailing .0 for whole numbers so "60" reads cleaner than "60.0".
  final rounded = double.parse(value.toStringAsFixed(decimals));
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toStringAsFixed(decimals);
}

/// Formats a kg value with its unit label, e.g. "60 kg" or "132.3 lbs".
String formatWeight(double kg, String units, {int decimals = 1}) =>
    '${formatWeightValue(kg, units, decimals: decimals)} $units';

/// The unit label for the active setting.
String unitLabel(String units) => units == 'lbs' ? 'lbs' : 'kg';
