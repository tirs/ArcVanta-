import 'package:intl/intl.dart';

/// Presentation-level formatting. Centralised so numeric and date rendering
/// stays identical everywhere, including the rule that low-confidence values
/// never carry misleading decimals.
abstract final class Fmt {
  /// Source of "now" for relative dates.
  ///
  /// Everything reads the time through here so tests and golden previews can
  /// pin it, rather than producing output that changes with the wall clock.
  static DateTime Function() currentTime = DateTime.now;

  static final _dayMonth = DateFormat('d MMM');
  static final _dayMonthYear = DateFormat('d MMM yyyy');
  static final _weekdayLong = DateFormat('EEEE');
  static final _weekdayShort = DateFormat('EEE');
  static final _time = DateFormat('HH:mm');
  static final _monthDayTime = DateFormat('d MMM, HH:mm');
  static final _monthYear = DateFormat('MMMM yyyy');

  static String date(DateTime value) => _dayMonth.format(value);
  static String fullDate(DateTime value) => _dayMonthYear.format(value);
  static String weekday(DateTime value) => _weekdayLong.format(value);
  static String weekdayShort(DateTime value) => _weekdayShort.format(value);
  static String time(DateTime value) => _time.format(value);
  static String dateTime(DateTime value) => _monthDayTime.format(value);
  static String monthYear(DateTime value) => _monthYear.format(value);

  static String duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  /// A running total narrow enough for a stat tile.
  ///
  /// Whole hours would round a first session down to "0h" and read as though
  /// nothing had been recorded, so anything under an hour stays in minutes and
  /// the hour range carries a decimal until it is long enough not to need one.
  static String spanShort(Duration value) {
    if (value.inMinutes < 60) return '${value.inMinutes}m';
    final hours = value.inMinutes / 60;
    if (hours < 10) return '${hours.toStringAsFixed(1)}h';
    return '${hours.round()}h';
  }

  static String clock(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (value.inHours > 0) {
      return '${value.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  static String relative(DateTime value, {DateTime? now}) {
    final reference = now ?? currentTime();
    final diff = reference.difference(value);
    if (diff.inSeconds.abs() < 60) return 'just now';
    if (diff.isNegative) {
      final ahead = diff.abs();
      if (ahead.inHours < 24) return 'in ${ahead.inHours}h';
      if (ahead.inDays == 1) return 'tomorrow';
      if (ahead.inDays < 7) return 'in ${ahead.inDays} days';
      return 'on ${date(value)}';
    }
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) {
      return '${count((diff.inDays / 7).floor(), 'week')} ago';
    }
    return date(value);
  }

  /// `3 sessions`, `1 session`. English only, and only for the regular `-s`
  /// case or an explicit [plural]; anything harder should be spelled out at
  /// the call site rather than guessed at here.
  static String count(int value, String singular, [String? plural]) =>
      '$value ${value == 1 ? singular : (plural ?? '${singular}s')}';

  static String percent(double value, {int decimals = 1}) =>
      '${value.toStringAsFixed(decimals)}%';

  static String signed(double value, {int decimals = 1, String unit = ''}) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(decimals)}$unit';

  static String degrees(double value, {int decimals = 1}) =>
      '${value.toStringAsFixed(decimals)}\u00B0';

  static String money(double value) =>
      value == 0 ? 'Free' : '\$${value.toStringAsFixed(2)}';

  static String compactCount(int value) {
    if (value < 1000) return '$value';
    if (value < 10000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '${(value / 1000).round()}k';
  }
}
