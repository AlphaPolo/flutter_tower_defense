import 'dart:math';

extension IterableExtension<E> on Iterable<E>{

  E randomChoose() {
    final random = Random().nextInt(length);
    return elementAt(random);
  }

  E firstOrElse(E Function() orElse) {
    Iterator<E> it = iterator;
    if (!it.moveNext()) {
      return orElse();
    }
    return it.current;
  }

  List<E> joinElement(E separator) {
    final list = <E>[];
    Iterator<E> iterator = this.iterator;
    if (!iterator.moveNext()) return list;
    if (separator == null) {
      do {
        list.add(iterator.current);
      } while (iterator.moveNext());
    } else {
      list.add(iterator.current);
      while (iterator.moveNext()) {
        list.add(separator);
        list.add(iterator.current);
      }
    }
    return list;
  }

  List<T> mapToList<T>(T Function(E e) toElement) => map(toElement).toList();

}