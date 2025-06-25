import 'package:flutter/material.dart';

class ResponsiveUtils {
  final BuildContext context;

  ResponsiveUtils(this.context);

  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;

  double spacing(double factor) {
    return screenWidth * factor;
  }

  double fontSize(double factor) {
    return screenWidth * factor;
  }

  double iconSize(double factor) {
    return screenWidth * factor;
  }

  double elevation(double factor) {
    return screenWidth * factor;
  }

  EdgeInsets paddingAll(double factor) {
    return EdgeInsets.all(spacing(factor));
  }

  EdgeInsets paddingOnly({
    double? top,
    double? right,
    double? bottom,
    double? left,
  }) {
    return EdgeInsets.only(
      top: top != null ? spacing(top) : 0,
      right: right != null ? spacing(right) : 0,
      bottom: bottom != null ? spacing(bottom) : 0,
      left: left != null ? spacing(left) : 0,
    );
  }

  EdgeInsets paddingSymmetric({double? vertical, double? horizontal}) {
    return EdgeInsets.symmetric(
      vertical: vertical != null ? spacing(vertical) : 0,
      horizontal: horizontal != null ? spacing(horizontal) : 0,
    );
  }
}
