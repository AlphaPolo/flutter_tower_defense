extension ObjectExtension on dynamic {

  T asType<T>() {
    return this as T;
  }

}