import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../data/areas/area_candidate_providers.dart';

/// The name and plumbing flag for a newly discovered area.
typedef DiscoveredArea = ({String name, bool isPlumbing});

/// "Add Newly Discovered Area" (QA #12): an area found on site that the
/// suggested list didn't include. Offers reviewed, approved names for
/// this property type as quick picks when there are any, but any name
/// can be typed. Returns null if cancelled.
Future<DiscoveredArea?> showDiscoveredAreaDialog(
  BuildContext context, {
  required String propertyType,
  Set<String> existingNames = const {},
}) {
  return showDialog<DiscoveredArea>(
    context: context,
    builder: (context) => _DiscoveredAreaDialog(
      propertyType: propertyType,
      existingNames: {for (final n in existingNames) n.toLowerCase()},
    ),
  );
}

class _DiscoveredAreaDialog extends ConsumerStatefulWidget {
  const _DiscoveredAreaDialog({
    required this.propertyType,
    required this.existingNames,
  });

  final String propertyType;
  final Set<String> existingNames;

  @override
  ConsumerState<_DiscoveredAreaDialog> createState() =>
      _DiscoveredAreaDialogState();
}

class _DiscoveredAreaDialogState extends ConsumerState<_DiscoveredAreaDialog> {
  final _controller = TextEditingController();
  bool _isPlumbing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name: name, isPlumbing: _isPlumbing));
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        (ref
                    .watch(approvedAreaSuggestionsProvider(widget.propertyType))
                    .value ??
                const <String>[])
            .where((n) => !widget.existingNames.contains(n.toLowerCase()))
            .toList();
    return AlertDialog(
      title: const Text('Add newly discovered area'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For an area this unit has that the suggested list '
              "doesn't. It's added to this inspection straight away.",
            ),
            const SizedBox(height: AppSpacing.md),
            if (suggestions.isNotEmpty) ...[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final name in suggestions)
                    ActionChip(
                      label: Text(name),
                      onPressed: () => setState(() => _controller.text = name),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Area name',
                hintText: 'e.g. Laundry Loft',
              ),
              onSubmitted: (_) => _submit(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Contains plumbing'),
              subtitle: const Text(
                'Inspected first (e.g. leakage/ponding checks)',
              ),
              value: _isPlumbing,
              onChanged: (value) => setState(() => _isPlumbing = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => FilledButton(
            onPressed: _controller.text.trim().isEmpty ? null : _submit,
            child: const Text('Add Area'),
          ),
        ),
      ],
    );
  }
}
