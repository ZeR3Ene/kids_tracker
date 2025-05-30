import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class CustomBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final double? size;

  const CustomBackButton({super.key, this.onPressed, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveUtils(context);
    return IconButton(
      icon: Icon(
        Icons.arrow_back_ios,
        size: size ?? responsive.iconSize(0.05),
        color: color ?? Theme.of(context).appBarTheme.foregroundColor,
      ),
      onPressed: onPressed ?? () => Navigator.pop(context),
    );
  }
}
