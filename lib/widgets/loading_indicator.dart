import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:petrol_pump/widgets/loading_indicator.dart';

class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color color;

  const LoadingIndicator({
    super.key,
    this.size = 40.0,
    this.color = AppTheme.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: CircularProgressIndicator(
        color: color,
        strokeWidth: 3.0,
      ),
    );
  }
}