import 'package:flutter/material.dart';
import 'package:boilerplate/core/widgets/app_form_fields.dart';

class DatePickerField extends StatefulWidget {
  const DatePickerField({super.key, required this.initialDate, this.onChanged, this.label, this.firstDate, this.lastDate});
  final DateTime initialDate;
  final ValueChanged<DateTime>? onChanged;
  final String? label;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  late DateTime _date;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    _controller = TextEditingController(text: _formatDate(_date));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      hint: 'Select Date',
      readOnly: true,
      suffixIcon: const Icon(Icons.calendar_today_outlined),
      onTap: _pick,
      controller: _controller,
    );
  }

  Future<void> _pick() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: widget.firstDate ?? DateTime(2020, 1, 1),
      lastDate: widget.lastDate ?? DateTime(2035, 12, 31),
      helpText: 'Select date',
      builder: (context, child) {
        final ThemeData base = Theme.of(context);
        const teal = Color(0xFF4db1b3);
        return Theme(
          data: base.copyWith(
            colorScheme: const ColorScheme.light(
              primary: teal,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: teal),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _date = picked);
      _controller.text = _formatDate(_date);
      widget.onChanged?.call(_date);
    }
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2, '0')}-${months[d.month - 1]}-${d.year}';
  }
}


