import 'package:flutter/material.dart';

class DateNavigator extends StatefulWidget {
  const DateNavigator({super.key, required this.initialDate, this.onChanged});
  final DateTime initialDate;
  final ValueChanged<DateTime>? onChanged;

  @override
  State<DateNavigator> createState() => _DateNavigatorState();
}

class _DateNavigatorState extends State<DateNavigator> {
  late DateTime _current;

  @override
  void initState() {
    super.initState();
    _current = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
  }

  @override
  Widget build(BuildContext context) {
    final Color border = Theme.of(context).dividerColor.withOpacity(.25);
    return Container(
      height: 56,
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: border)),
        color: Colors.white,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: _prev,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: _pick,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _format(_current),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: _next,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _prev() => _set(_current.subtract(const Duration(days: 1)));
  void _next() => _set(_current.add(const Duration(days: 1)));

  Future<void> _pick() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _current,
      firstDate: DateTime(2017, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      helpText: 'Select date',
    );
    if (picked != null) _set(picked);
  }

  void _set(DateTime d) {
    setState(() => _current = d);
    widget.onChanged?.call(_current);
  }

  String _format(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${weekdays[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}-${months[d.month - 1]}-${d.year}';
  }
}



