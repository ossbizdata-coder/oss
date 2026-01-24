import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? child;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.fullWidth = true,
    this.backgroundColor,
    this.foregroundColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: isDisabled ? 0 : 2,
          backgroundColor: isDisabled
              ? Colors.grey.shade200
              : (backgroundColor ?? Theme.of(context).primaryColor),
          foregroundColor:
          isDisabled ? Colors.grey.shade600 : (foregroundColor ?? Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: child ?? FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDisabled ? Colors.grey.shade600 : (foregroundColor ?? Colors.white),
              inherit: true,
            ),
          ),
        ),
      ),
    );
  }
}
