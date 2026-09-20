import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/new_inspection_draft_providers.dart';
import '../../providers/user_profile_providers.dart';
import 'area_configuration_screen.dart';
import 'property_type_selection_screen.dart';

/// New Inspection setup, step 2 ("Basic Details" — after property type,
/// before area configuration): the property/report metadata that later
/// populates the dashboard card, Report Readiness header, and the
/// generated PDF's cover page — see
/// `docs/home_inspection_product_flow.md`.
///
/// Only [PropertyDetails.unitNumber] is required — every other field,
/// including the property title, is skippable and can be completed
/// later via Report Details (see the QA/QC setup-simplification pass:
/// "GET THE INSPECTOR TO THE CAMERA AS FAST AS POSSIBLE"). Purely
/// in-memory (edits [NewInspectionDraft], not a persisted session) —
/// consistent with every other New Inspection setup step.
class PropertyDetailsScreen extends ConsumerStatefulWidget {
  const PropertyDetailsScreen({super.key});

  static const routePath = '/home-inspection/property-details';

  @override
  ConsumerState<PropertyDetailsScreen> createState() =>
      _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends ConsumerState<PropertyDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _address = TextEditingController();
  final _projectDeveloperName = TextEditingController();
  final _blockTower = TextEditingController();
  final _unitNumber = TextEditingController();
  final _clientName = TextEditingController();
  final _inspectorName = TextEditingController();
  final _contactNumber = TextEditingController();
  DateTime _inspectionDate = DateTime.now();
  bool _prefilledInspector = false;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _address,
      _projectDeveloperName,
      _blockTower,
      _unitNumber,
      _clientName,
      _inspectorName,
      _contactNumber,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prefill the inspector name from the on-device profile once, the
    // first time it loads — never overwrites text the inspector already
    // typed on a rebuild.
    if (!_prefilledInspector) {
      final profile = ref.watch(userProfileProvider).value;
      if (profile?.inspectorName != null) {
        _inspectorName.text = profile!.inspectorName!;
        _prefilledInspector = true;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Basic Details')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const AppWizardStepper(
                stepLabels: PropertyTypeSelectionScreen.wizardSteps,
                currentIndex: 1,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Only Unit No. is required — everything else can be '
                'completed later.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppFormSectionCard(
                icon: Icons.home_outlined,
                title: 'Property',
                subtitle: 'Basic information about the property',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _unitNumber,
                          'Unit No.',
                          required: true,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _field(_blockTower, 'Block / Tower')),
                    ],
                  ),
                  _field(
                    _title,
                    'Inspection / Property title',
                    textCapitalization: TextCapitalization.words,
                  ),
                  _field(
                    _projectDeveloperName,
                    'Project / Developer Name',
                    textCapitalization: TextCapitalization.words,
                  ),
                  _field(
                    _address,
                    'Property address',
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppFormSectionCard(
                icon: Icons.people_outline,
                title: 'Client',
                subtitle: 'Client or owner information',
                children: [
                  _field(
                    _clientName,
                    'Client / Agent Name',
                    textCapitalization: TextCapitalization.words,
                  ),
                  _field(
                    _contactNumber,
                    'Client / Agent Contact Number',
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppFormSectionCard(
                icon: Icons.event_available_outlined,
                title: 'Inspection',
                subtitle: 'Assign the inspector and schedule',
                children: [
                  _field(
                    _inspectorName,
                    'Inspector name',
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppDateTimeField(
                    label: 'Inspection date',
                    value: _inspectionDate,
                    onChanged: (date) => setState(() => _inspectionDate = date),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: _continue,
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _continue,
                child: const Text('Skip optional details / Complete later'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        textCapitalization: textCapitalization,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        decoration: InputDecoration(labelText: required ? '$label *' : label),
        validator: required
            ? (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  /// Validates only [PropertyDetails.unitNumber] — every other field is
  /// deferrable, and "Skip optional details" reaches the exact same
  /// handler (there's nothing else to skip past once Unit No. itself is
  /// filled in).
  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    String? orNull(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    ref
        .read(newInspectionDraftProvider.notifier)
        .updatePropertyDetails(
          PropertyDetails(
            title: _title.text.trim(),
            address: orNull(_address),
            projectDeveloperName: orNull(_projectDeveloperName),
            blockTower: orNull(_blockTower),
            unitNumber: orNull(_unitNumber),
            clientName: orNull(_clientName),
            inspectorName: orNull(_inspectorName),
            contactNumber: orNull(_contactNumber),
            inspectionDate: _inspectionDate,
          ),
        );
    context.push(AreaConfigurationScreen.routePath);
  }
}
