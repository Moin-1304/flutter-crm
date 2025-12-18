import 'package:flutter/material.dart';
import 'package:boilerplate/constants/dimens.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
            ),
          )
        : Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          );

    final style = FilledButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: theme.colorScheme.primary,
      elevation: 2,
      shadowColor: theme.colorScheme.primary.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.buttonBorderRadius),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.buttonPaddingHorizontal,
        vertical: Dimens.buttonPaddingVertical,
      ),
      minimumSize: Size(width ?? 0, Dimens.buttonHeight),
    );

    final button = icon == null
        ? FilledButton(onPressed: isLoading ? null : onPressed, style: style, child: child)
        : FilledButton.icon(
            onPressed: isLoading ? null : onPressed,
            style: style,
            icon: isLoading ? const SizedBox.shrink() : Icon(icon, size: 22),
            label: child,
          );

    return width != null
        ? SizedBox(width: width, child: button)
        : SizedBox(width: double.infinity, child: button);
  }
}

class AppTonalButton extends StatelessWidget {
  const AppTonalButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          )
        : Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          );

    final style = FilledButton.styleFrom(
      foregroundColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.primaryContainer,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.buttonBorderRadius),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.buttonPaddingHorizontal,
        vertical: Dimens.buttonPaddingVertical,
      ),
      minimumSize: const Size(0, Dimens.buttonHeight),
    );

    return icon == null
        ? FilledButton.tonal(onPressed: isLoading ? null : onPressed, style: style, child: child)
        : FilledButton.tonalIcon(
            onPressed: isLoading ? null : onPressed,
            style: style,
            icon: isLoading ? const SizedBox.shrink() : Icon(icon, size: 22),
            label: child,
          );
  }
}

class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          )
        : Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          );

    final style = OutlinedButton.styleFrom(
      foregroundColor: theme.colorScheme.primary,
      side: BorderSide(color: theme.colorScheme.primary, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.buttonBorderRadius),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.buttonPaddingHorizontal,
        vertical: Dimens.buttonPaddingVertical,
      ),
      minimumSize: const Size(0, Dimens.buttonHeight),
    );

    return icon == null
        ? OutlinedButton(onPressed: isLoading ? null : onPressed, style: style, child: child)
        : OutlinedButton.icon(
            onPressed: isLoading ? null : onPressed,
            style: style,
            icon: isLoading ? const SizedBox.shrink() : Icon(icon, size: 22),
            label: child,
          );
  }
}



