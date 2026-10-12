import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/physical_inspection_providers.dart';
import '../widgets/residence_photo_section.dart';

/// "Report Details" — lets the inspector review/edit the report's
/// cover-page metadata right before generating, without going all the
/// way back to Property Details. Pre-filled from the inspector-
/// confirmed `ReportMetadata` if this session already has one, else
/// from `PropertyDetails` (the original New Inspection setup) plus
/// today as the report date. Saving here never touches
/// `PropertyDetails` — see `ReportMetadata`'s doc comment.
class ReportDetailsScreen extends ConsumerStatefulWidget {
  const ReportDetailsScreen({super.key});

  static const routePath = '/home-inspection/report-details';

  @override
  ConsumerState<ReportDetailsScreen> createState() =>
      _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends ConsumerState<ReportDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _projectDeveloperName = TextEditingController();
  final _address = TextEditingController();
  final _blockTower = TextEditingController();
  final _unitNumber = TextEditingController();
  final _clientName = TextEditingController();
  final _inspectorName = TextEditingController();
  final _contactNumber = TextEditingController();
  DateTime _inspectionDate = DateTime.now();
  DateTime _reportDate = DateTime.now();
  bool _prefilled = false;
  bool _pickingPhoto = false;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _projectDeveloperName,
      _address,
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

  /// The Residence / Unit Photo is written straight to the session (the one
  /// source of truth shared with setup and Inspection Overview), not held in
  /// this form — so Add / Replace / Remove take effect immediately.
  Future<void> _chooseCoverPhoto(EvidenceSource source) async {
    setState(() => _pickingPhoto = true);
    try {
      await ref
          .read(activeSessionProvider.notifier)
          .chooseResidencePhoto(source);
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
    if (!mounted) return;
    final error = ref.read(activeSessionErrorProvider);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      ref.read(activeSessionErrorProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Details')),
        body: const AppEmptyView(
          icon: Icons.error_outline,
          title: 'No active inspection.',
        ),
      );
    }

    if (!_prefilled) {
      final metadata =
          session.reportMetadata ??
          ReportMetadata.fromPropertyDetails(session.propertyDetails);
      _title.text = metadata.title;
      _projectDeveloperName.text = metadata.projectDeveloperName ?? '';
      _address.text = metadata.address ?? '';
      _blockTower.text = metadata.blockTower ?? '';
      _unitNumber.text = metadata.unitNumber ?? '';
      _clientName.text = metadata.clientName ?? '';
      _inspectorName.text = metadata.inspectorName ?? '';
      _contactNumber.text = metadata.contactNumber ?? '';
      _inspectionDate = metadata.inspectionDate ?? DateTime.now();
      _reportDate = metadata.reportDate ?? DateTime.now();
      _prefilled = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Report-only metadata for the cover page — this does not '
                'change the inspection\'s original Property Details.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              ResidencePhotoSection(
                path: session.reportMetadata?.coverPhotoPath,
                // A completed inspection is read-only.
                busy: _pickingPhoto || ref.watch(inspectionReadOnlyProvider),
                onChoose: _chooseCoverPhoto,
                onRemove: ref
                    .read(activeSessionProvider.notifier)
                    .removeResidencePhoto,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppFormSectionCard(
                icon: Icons.home_outlined,
                title: 'Property',
                subtitle: 'As it will appear on the cover page',
                children: [
                  _field(_title, 'Property / Inspection title'),
                  _field(_projectDeveloperName, 'Project / Developer Name'),
                  _field(_address, 'Address'),
                  Row(
                    children: [
                      Expanded(child: _field(_blockTower, 'Block / Tower')),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: _field(_unitNumber, 'Unit')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppFormSectionCard(
                icon: Icons.people_outline,
                title: 'Client & Inspector',
                subtitle: 'Who this report is for and by',
                children: [
                  _field(_clientName, 'Client / Owner'),
                  _field(
                    _contactNumber,
                    'Client / Agent Contact Number',
                    keyboardType: TextInputType.phone,
                  ),
                  _field(_inspectorName, 'Inspector', last: true),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppFormSectionCard(
                icon: Icons.event_available_outlined,
                title: 'Dates',
                subtitle: 'Inspection and report dates',
                children: [
                  AppDateTimeField(
                    label: 'Inspection date',
                    value: _inspectionDate,
                    onChanged: (date) => setState(() => _inspectionDate = date),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DatePickerField(
                    label: 'Report date',
                    date: _reportDate,
                    onPick: (date) => setState(() => _reportDate = date),
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
          child: FilledButton(
            onPressed: () => _save(session.id),
            child: const Text('Save'),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool last = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        keyboardType: keyboardType,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  void _save(String sessionId) {
    if (!_formKey.currentState!.validate()) return;
    String? orNull(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    ref
        .read(activeSessionProvider.notifier)
        .setReportMetadata(
          ReportMetadata(
            title: _title.text.trim(),
            projectDeveloperName: orNull(_projectDeveloperName),
            address: orNull(_address),
            blockTower: orNull(_blockTower),
            unitNumber: orNull(_unitNumber),
            clientName: orNull(_clientName),
            inspectorName: orNull(_inspectorName),
            contactNumber: orNull(_contactNumber),
            inspectionDate: _inspectionDate,
            reportDate: _reportDate,
            coverPhotoPath: ref
                .read(activeSessionProvider)
                ?.reportMetadata
                ?.coverPhotoPath,
          ),
        );
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Report details saved.')));
    context.pop();
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onPick,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(_formatDate(date)),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${dateTime.year}-${twoDigits(dateTime.month)}-${twoDigits(dateTime.day)}';
  }
}
