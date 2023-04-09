extension KotlinLikeExtensions <T> on T {
  R let<R>(R Function(T) op) => op(this);
}