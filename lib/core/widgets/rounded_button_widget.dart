import 'package:flutter/material.dart';
import 'package:boilerplate/constants/dimens.dart';

class RoundedButtonWidget extends StatelessWidget {
  final String? buttonText;
  final Color? buttonColor;
  final Color textColor;
  final Color? borderColor;
  final String? imagePath;
  final double buttonTextSize;
  final double? height;
  final double? width;
  final VoidCallback? onPressed;
  final ShapeBorder shape;
  final bool isLoading;

  const RoundedButtonWidget({
    super.key,
    this.buttonText,
    this.buttonColor,
    this.textColor = Colors.white,
    this.onPressed,
    this.imagePath,
    this.borderColor,
    this.shape = const StadiumBorder(),
    this.buttonTextSize = 16.0,
    this.height,
    this.width,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = buttonColor ?? theme.colorScheme.primary;
    final borderRadius = BorderRadius.circular(Dimens.buttonBorderRadius);
    
    return Material(
      color: borderColor != null ? Colors.transparent : effectiveColor,
      shape: shape is StadiumBorder 
          ? shape 
          : RoundedRectangleBorder(borderRadius: borderRadius),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: shape is StadiumBorder ? null : borderRadius,
        child: Container(
          height: height ?? Dimens.buttonHeight,
          width: width,
          decoration: borderColor != null
              ? BoxDecoration(
                  border: Border.all(color: borderColor!, width: 2),
                  borderRadius: borderRadius,
                )
              : null,
          padding: const EdgeInsets.symmetric(
            horizontal: Dimens.buttonPaddingHorizontal,
            vertical: Dimens.buttonPaddingVertical,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isLoading)
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              else ...[
                if (imagePath != null) ...[
                  Image.asset(
                    imagePath!,
                    height: 20.0,
                  ),
                  const SizedBox(width: 8.0),
                ],
                Flexible(
                  child: Text(
                    buttonText ?? '',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: buttonTextSize,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
