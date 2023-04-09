extension ComparatorExtension<T> on Comparator<T> {
  Comparator<T> thenComparing(Comparator<T> other) {
    return (t1, t2) {
      final result = call(t1, t2);
      return result != 0 ? result : other.call(t1, t2);
    };
  }
}