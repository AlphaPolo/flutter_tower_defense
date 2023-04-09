import 'package:vector_math/vector_math.dart';

class HexMetrics {

  static const double outerRadius = 10;

  static const double innerRadius = outerRadius * 0.866025404;

  static final List<Vector3> corners = [
    Vector3(0, 0, outerRadius),
    Vector3(innerRadius, 0, 0.5 * outerRadius),
    Vector3(innerRadius, 0, -0.5 * outerRadius),
    Vector3(0, 0, -outerRadius),
    Vector3(-innerRadius, 0, -0.5 * outerRadius),
    Vector3(-innerRadius, 0, 0.5 * outerRadius)
  ];
}