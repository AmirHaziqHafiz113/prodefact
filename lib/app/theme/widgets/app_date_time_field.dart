import 'package:flutter/material.dart';

import '../app_metrics.dart';

/// A single "Inspection Date & Time" input: a date picker and a time
/// picker side by side, always combined into one [DateTime] — never
/// two separate display-only strings (see the QA/QC simplification
/// pass, "Inspection Date & Time"). Picking a new date preserves the
/// existing time-of-day, and picking a new time preserves the existing
/// date — neither picker ever resets the other half of [value].
class AppDateTimeField extends StatelessWidget {
  const AppDateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: () => _pickDate(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              child: Text(_formatDate(value)),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: () => _pickTime(context),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Time',
                suffixIcon: Icon(Icons.access_time_outlined),
              ),
              child: Text(_formatTime(value)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    onChanged(
      DateTime(picked.year, picked.month, picked.day, value.hour, value.minute),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (picked == null) return;
    onChanged(
      DateTime(value.year, value.month, value.day, picked.hour, picked.minute),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int v) => v.toString().padLeft(2, '0');
    return '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}
