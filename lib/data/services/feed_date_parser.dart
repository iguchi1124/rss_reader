const _months = <String, int>{
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// Named zones mapped to their offset from UTC in minutes. Covers what RFC 822
/// defines plus the abbreviations that show up in real feeds.
const _namedZones = <String, int>{
  'ut': 0,
  'utc': 0,
  'gmt': 0,
  'z': 0,
  'est': -5 * 60,
  'edt': -4 * 60,
  'cst': -6 * 60,
  'cdt': -5 * 60,
  'mst': -7 * 60,
  'mdt': -6 * 60,
  'pst': -8 * 60,
  'pdt': -7 * 60,
  'jst': 9 * 60,
};

final _rfc822 = RegExp(
  r'^(?:[A-Za-z]{3,9},\s*)?'
  r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{2,4})'
  r'\s+(\d{1,2}):(\d{2})(?::(\d{2}))?'
  r'(?:\s+([+-]\d{4}|[A-Za-z]{1,3}))?\s*$',
);

/// Parses a feed timestamp into UTC.
///
/// Atom specifies ISO 8601 and RSS 2.0 specifies RFC 822, but feeds mix the two
/// and often omit the zone. Unparseable input yields null so the caller can
/// fall back to the fetch time.
DateTime? parseFeedDate(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;

  // Covers Atom's ISO 8601 and the "2026-08-02 14:48:00" form seen in RSS.
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso.toUtc();

  final match = _rfc822.firstMatch(value);
  if (match == null) return null;

  final month = _months[match.group(2)!.toLowerCase()];
  if (month == null) return null;

  final day = int.parse(match.group(1)!);
  var year = int.parse(match.group(3)!);
  // RFC 822 two-digit years still turn up occasionally in RSS.
  if (year < 100) year += year < 70 ? 2000 : 1900;

  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6) ?? '0');

  final parsed = DateTime.utc(year, month, day, hour, minute, second);
  return parsed.subtract(Duration(minutes: _offsetMinutes(match.group(7))));
}

/// Missing or unrecognised zones are treated as UTC.
int _offsetMinutes(String? zone) {
  if (zone == null || zone.isEmpty) return 0;

  final named = _namedZones[zone.toLowerCase()];
  if (named != null) return named;

  if (zone.length == 5 && (zone[0] == '+' || zone[0] == '-')) {
    final hours = int.tryParse(zone.substring(1, 3));
    final minutes = int.tryParse(zone.substring(3, 5));
    if (hours == null || minutes == null) return 0;
    final magnitude = hours * 60 + minutes;
    return zone[0] == '-' ? -magnitude : magnitude;
  }

  return 0;
}
