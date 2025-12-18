import 'package:flutter/material.dart';
import 'package:boilerplate/constants/dimens.dart';

class TextFieldWidget extends StatelessWidget {
  final IconData icon;
  final String? hint;
  final String? errorText;
  final bool isObscure;
  final bool isIcon;
  final TextInputType? inputType;
  final TextEditingController textController;
  final EdgeInsets padding;
  final Color? hintColor;
  final Color? iconColor;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autoFocus;
  final TextInputAction? inputAction;
  final int? maxLength;
  final String? labelText;
  final Widget? suffixIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: padding,
      child: TextFormField(
        controller: textController,
        focusNode: focusNode,
        onFieldSubmitted: onFieldSubmitted,
        onChanged: onChanged,
        autofocus: autoFocus,
        textInputAction: inputAction,
        obscureText: isObscure,
        maxLength: maxLength,
        keyboardType: inputType,
        enabled: enabled,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: 15,
          letterSpacing: 0.15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          labelText: labelText,
          prefixIcon: isIcon 
              ? Icon(
                  icon, 
                  color: iconColor ?? colorScheme.onSurface.withOpacity(0.7),
                  size: 22,
                ) 
              : null,
          suffixIcon: suffixIcon,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: hintColor ?? colorScheme.onSurface.withOpacity(0.5),
            fontSize: 15,
          ),
          labelStyle: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          errorText: errorText,
          errorStyle: theme.textTheme.bodySmall?.copyWith(
            color: Colors.red.shade400,
            fontSize: 12,
          ),
          counterText: maxLength != null ? '' : null,
          filled: true,
          fillColor: colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Dimens.inputPaddingHorizontal,
            vertical: Dimens.inputPaddingVertical,
          ),
        ),
      ),
    );
  }

  const TextFieldWidget({
    super.key,
    required this.icon,
    this.errorText,
    required this.textController,
    this.inputType,
    this.hint,
    this.isObscure = false,
    this.isIcon = true,
    this.padding = const EdgeInsets.all(0),
    this.hintColor,
    this.iconColor,
    this.focusNode,
    this.onFieldSubmitted,
    this.onChanged,
    this.autoFocus = false,
    this.inputAction,
    this.maxLength,
    this.labelText,
    this.suffixIcon,
    this.enabled = true,
  });
}
