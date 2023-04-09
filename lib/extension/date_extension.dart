// import 'package:intl/intl.dart';

extension DateOnlyCompare on DateTime {
  // bool isSameDate(DateTime other) {
  //   return year == other.year && month == other.month
  //       && day == other.day;
  // }

  // String toFormatString(String format) {
  //   DateFormat dateFormat = DateFormat(format);
  //   return dateFormat.format(this);
  // }

  DateTime clamp({DateTime? min, DateTime? max}) {
    assert(
    ((min != null) && (max != null)) ? (min.isBefore(max) || (min == max)) : true,
    'DateTime min has to be before or equal to max\n(min: $min - max: $max)',
    );
    if ((min != null) && compareTo(min).isNegative) {
      return min;
    } else if ((max != null) && max.compareTo(this).isNegative) {
      return max;
    }
    return this;
  }
}