import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/custom_catalogue_providers.dart';

/// "+ Add New": lets an inspector add a defect (and, if needed, a new
/// component) that the ProDefact master catalogue lacks. The entry is
/// saved to THIS company's own catalogue only — it is never added to the
/// master catalogue and is never visible to another company. Returns the
/// new, immediately selectable entry, or null if cancelled.
Future<DefectCatalogueEntry?> showAddCustomDefectDialog(
  BuildContext context, {
  String initialDescription = '',
}) {
  return showDialog<DefectCatalogueEntry>(
    context: context,
    builder: (context) =>
        _AddCustomDefectDialog(initialDescription: initialDescription),
  );
}

String _problemText(CustomDefectProblem problem) => switch (problem) {
  CustomDefectProblem.blankElement => 'Choose or type an element.',
  CustomDefectProblem.blankComponent => 'Choose or type a component.',
  CustomDefectProblem.blankDescription => 'Describe the defect.',
  CustomDefectProblem.blankCorrectiveAction =>
    'Add the corrective action to recommend.',
  CustomDefectProblem.exactDuplicate =>
    'This defect already exists under that element and component.',
};

class _AddCustomDefectDialog extends ConsumerStatefulWidget {
  const _AddCustomDefectDialog({required this.initialDescription});

  final String initialDescription;

  @override
  ConsumerState<_AddCustomDefectDialog> createState() =>
      _AddCustomDefectDialogState();
}

class _AddCustomDefectDialogState
    extends ConsumerState<_AddCustomDefectDialog> {
  final _element = TextEditingController();
  final _component = TextEditingController();
  late final _description = TextEditingController(
    text: widget.initialDescription,
  );
  final _action = TextEditingController();
  final _note = TextEditingController();
  final _elementFocus = FocusNode();
  final _componentFocus = FocusNode();
  String? _error;
  DefectCatalogueEntry? _nearDuplicate;
  bool _saving = false;

  @override
  void dispose() {
    _element.dispose();
    _component.dispose();
    _description.dispose();
    _action.dispose();
    _note.dispose();
    _elementFocus.dispose();
    _componentFocus.dispose();
    super.dispose();
  }

  Iterable<String> _elementOptions(String typed) {
    final names = {
      for (final e in DefectCatalogue.instance.mainElements) e.name,
    };
    final q = typed.trim().toLowerCase();
    return names.where((n) => q.isEmpty || n.toLowerCase().contains(q));
  }

  Iterable<String> _componentOptions(String typed) {
    final element = _element.text.trim().toLowerCase();
    final names = {
      for (final e in DefectCatalogue.instance.entries)
        if (element.isEmpty || e.mainElementName.toLowerCase() == element)
          e.componentName,
    };
    final q = typed.trim().toLowerCase();
    return names.where((n) => q.isEmpty || n.toLowerCase().contains(q));
  }

  Future<void> _save({bool ignoreNearDuplicate = false}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = ref.read(customCatalogueProvider.notifier);
    final catalogue = DefectCatalogue.instance;
    if (!ignoreNearDuplicate) {
      final check = validateCustomDefect(
        element: _element.text,
        component: _component.text,
        description: _description.text,
        correctiveAction: _action.text,
        existing: catalogue.entries,
      );
      if (check.isValid && check.nearDuplicate != null) {
        setState(() {
          _saving = false;
          _nearDuplicate = check.nearDuplicate;
        });
        return;
      }
    }
    final result = await notifier.add(
      element: _element.text,
      component: _component.text,
      description: _description.text,
      correctiveAction: _action.text,
      note: _note.text,
    );
    if (!mounted) return;
    if (result.saved) {
      Navigator.of(context).pop(result.entry);
      return;
    }
    final problem = result.validation?.problem;
    setState(() {
      _saving = false;
      _error = problem == null
          ? 'Could not save — please sign in and try again.'
          : _problemText(problem);
    });
  }

  Widget _autocomplete({
    required Key fieldKey,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required Iterable<String> Function(String) options,
    String? helper,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (value) => options(value.text),
      onSelected: (value) => controller.text = value,
      fieldViewBuilder: (context, textController, focusNode, onSubmit) =>
          TextField(
            key: fieldKey,
            controller: textController,
            focusNode: focusNode,
            decoration: InputDecoration(labelText: label, helperText: helper),
          ),
      optionsViewBuilder: (context, onSelected, items) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final item in items)
                  ListTile(
                    dense: true,
                    title: Text(item),
                    onTap: () => onSelected(item),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a defect to your catalogue'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved to your company\'s own catalogue only. It is not added '
              'to the ProDefact master catalogue.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _autocomplete(
              fieldKey: const ValueKey('custom-defect-element'),
              label: 'Element',
              controller: _element,
              focusNode: _elementFocus,
              options: _elementOptions,
            ),
            _autocomplete(
              fieldKey: const ValueKey('custom-defect-component'),
              label: 'Component',
              controller: _component,
              focusNode: _componentFocus,
              options: _componentOptions,
              helper: 'Type a new name to add a new component.',
            ),
            TextField(
              key: const ValueKey('custom-defect-description'),
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Defect description',
              ),
            ),
            TextField(
              key: const ValueKey('custom-defect-action'),
              controller: _action,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Corrective action'),
            ),
            TextField(
              key: const ValueKey('custom-defect-note'),
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            if (_nearDuplicate != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Similar defect already exists: '
                  '"${_nearDuplicate!.defectDescription}". Use that one '
                  'instead, or save yours anyway.',
                  key: const ValueKey('custom-defect-near-duplicate'),
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _error!,
                  key: const ValueKey('custom-defect-error'),
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('custom-defect-save'),
          onPressed: _saving
              ? null
              : () => _save(ignoreNearDuplicate: _nearDuplicate != null),
          child: Text(_nearDuplicate != null ? 'Save Anyway' : 'Save'),
        ),
      ],
    );
  }
}
