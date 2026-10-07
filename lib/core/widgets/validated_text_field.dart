import 'package:flutter/material.dart';

/// ValidatedTextField provides an inline validation form field.
class ValidatedTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final String? tooltipText;
  final Iterable<String>? autofillHints;

  const ValidatedTextField({
    super.key,
    required this.label,
    this.hint,
    this.validator,
    this.controller,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.obscureText = false,
    this.onChanged,
    this.tooltipText,
    this.autofillHints,
  });

  @override
  ValidatedTextFieldState createState() => ValidatedTextFieldState();
}

class ValidatedTextFieldState extends State<ValidatedTextField> {
  bool? _isValid;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    Widget? builtSuffixIcon = widget.suffixIcon;

    if (_isValid != null) {
      builtSuffixIcon = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.suffixIcon != null) widget.suffixIcon!,
          if (_isValid == true)
            const Icon(Icons.check_circle, color: Colors.green)
          else if (_isValid == false)
            const Icon(Icons.cancel, color: Colors.red),
          if (widget.tooltipText != null)
            Tooltip(
              message: widget.tooltipText!,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(Icons.info_outline, size: 20),
              ),
            ),
        ],
      );
    } else if (widget.tooltipText != null) {
      builtSuffixIcon = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.suffixIcon != null) widget.suffixIcon!,
          Tooltip(
            message: widget.tooltipText!,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Icon(Icons.info_outline, size: 20),
            ),
          ),
        ],
      );
    }

    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon,
        suffixIcon: builtSuffixIcon,
        errorText: _errorText,
      ),
      validator: (value) {
        if (widget.validator != null) {
          final result = widget.validator!(value);
          setState(() {
            _isValid = result == null;
            _errorText = result;
          });
          return result;
        }
        return null;
      },
      onChanged: (value) {
        if (widget.onChanged != null) {
          widget.onChanged!(value);
        }
        if (widget.validator != null) {
          final result = widget.validator!(value);
          setState(() {
            _isValid = result == null;
            _errorText = result;
          });
        }
      },
    );
  }
}
