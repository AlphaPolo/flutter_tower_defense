extension NumToDurationExtension on int {

  Duration get minutes => Duration(minutes: this);
  Duration get seconds => Duration(seconds: this);
  Duration get ms => Duration(milliseconds: this);

}