import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/backup/drive_backup.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../config/property_type.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/drive_backup_providers.dart';
import '../widgets/finding_status_presentation.dart';
import '../widgets/session_navigation.dart';
import '../widgets/session_status_presentation.dart';
import 'areas_screen.dart';
import 'finding_detail_screen.dart';
import 'report_screen.dart';

/// The location of [sessionId]'s Past Inspection Detail.
String pastInspectionLocation(String sessionId) =>
    '${PastInspectionDetailScreen.routePathPrefix}/$sessionId';

/// A completed inspection, read-only: the historical record of one
/// property. Editing a completed inspection isn't possible yet (no
/// reopen/revision flow) — every screen reached from here hides its
/// editing controls (see `inspectionReadOnlyProvider`). See
/// docs/ux_architecture.md ("Past Inspections").
class PastInspectionDetailScreen extends ConsumerStatefulWidget {
  const PastInspectionDetailScreen({super.key, required this.sessionId});

  static const routePathPrefix = '/home-inspection/past';

  final String sessionId;

  @override
  ConsumerState<PastInspectionDetailScreen> createState() =>
      _PastInspectionDetailScreenState();
}

class _PastInspectionDetailScreenState
    extends ConsumerState<PastInspectionDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Opened by link with another inspection active: make this one the
    // open (read-only) inspection so Areas/Findings/Report show it.
    if (ref.read(activeSessionProvider)?.id != widget.sessionId) {
      Future.microtask(
        () => ref.read(activeSessionProvider.notifier).resume(widget.sessionId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null || session.id != widget.sessionId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Past Inspection')),
        body: const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: AppSkeletonCardList(count: 2),
        ),
      );
    }

    final details = session.propertyDetails;
    final metadata = session.reportMetadata;
    final propertyType = PropertyType.values.firstWhereOrNull(
      (p) => p.name == session.assetTypeId,
    );
    final title = details.title.isNotEmpty
        ? details.title
        : (propertyType?.label ?? session.assetTypeId);
    final report = session.report;
    final inspector = metadata?.inspectorName ?? details.inspectorName;
    final client = metadata?.clientName ?? details.clientName;
    final suggestions = activeSuggestionsOf(session);
    final statuses = [
      for (final f in session.findings)
        findingStatusOf(
          f,
          suggestions.firstWhereOrNull((s) => s.findingId == f.id),
        ).$1,
    ];
    final confirmed = statuses.where((s) => s == AppStatus.confirmed).length;
    final unresolved = statuses.length - confirmed;
    final areas = inspectedAreasOf(session);
    final photoCount = session.findings.fold<int>(
      0,
      (sum, f) => sum + f.evidence.length,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Past Inspection')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => AppPropertyPhoto(
                    photoPath: metadata?.coverPhotoPath,
                    kind: illustrationKindFor(session.assetTypeId),
                    width: constraints.maxWidth,
                    height: 132,
                    radius: 0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const AppStatusChip(
                            status: AppStatus.completed,
                            dense: false,
                          ),
                        ],
                      ),
                      if (details.address?.isNotEmpty == true)
                        _Fact(
                          icon: Icons.place_outlined,
                          text: details.address!,
                        ),
                      _Fact(
                        icon: Icons.event_outlined,
                        text:
                            'Inspected '
                            '${formatInspectionDate(details.inspectionDate ?? session.createdAt)}',
                      ),
                      if (report != null)
                        _Fact(
                          icon: Icons.task_alt,
                          text:
                              'Completed ${formatInspectionDate(report.generatedAt)}',
                        ),
                      if (inspector?.isNotEmpty == true)
                        _Fact(
                          icon: Icons.badge_outlined,
                          text: 'Inspector: $inspector',
                        ),
                      if (client?.isNotEmpty == true)
                        _Fact(
                          icon: Icons.person_outline,
                          text: 'Client / purchaser: $client',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: session.findings.length,
                          label: 'Findings',
                        ),
                      ),
                      Expanded(
                        child: _Stat(value: confirmed, label: 'Confirmed'),
                      ),
                      Expanded(
                        child: _Stat(value: unresolved, label: 'Unresolved'),
                      ),
                      Expanded(
                        child: _Stat(value: areas.length, label: 'Areas'),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.xl),
                  Row(
                    key: const ValueKey('past-report-status'),
                    children: [
                      Icon(
                        report == null
                            ? Icons.picture_as_pdf_outlined
                            : Icons.picture_as_pdf,
                        color: report == null
                            ? AppColors.textMuted
                            : AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          report == null
                              ? 'Report file not on this device'
                              : 'Report v${report.version} · generated '
                                    '${formatInspectionDate(report.generatedAt)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (areas.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const AppSectionHeader(title: 'Area summary'),
            AppGroupedList(
              children: [
                for (final area in areas)
                  ListTile(
                    dense: false,
                    leading: Icon(
                      area.isPlumbing
                          ? Icons.plumbing_outlined
                          : Icons.chair_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(area.name),
                    trailing: Text(
                      '${session.findings.where((f) => f.sectionId == area.id).length} '
                      'finding'
                      '${session.findings.where((f) => f.sectionId == area.id).length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppGroupedList(
            children: [
              AppActionRow(
                key: const ValueKey('past-view-areas'),
                icon: Icons.grid_view_rounded,
                title: 'View Areas',
                subtitle: '${areas.length} inspected',
                onTap: () => context.push(AreasScreen.routePath),
              ),
              AppActionRow(
                key: const ValueKey('past-view-findings'),
                icon: Icons.fact_check_outlined,
                title: 'View Findings',
                subtitle: '${session.findings.length} findings',
                onTap: () => context.push(PastFindingsScreen.routePath),
              ),
              AppActionRow(
                key: const ValueKey('past-view-report'),
                icon: Icons.picture_as_pdf_outlined,
                title: 'View Report',
                subtitle: report == null
                    ? 'Open the report'
                    : 'Report v${report.version}',
                onTap: () => context.push(ReportScreen.routePath),
              ),
              AppActionRow(
                key: const ValueKey('past-view-photos'),
                icon: Icons.photo_library_outlined,
                title: 'View Photos',
                subtitle: '$photoCount photos',
                onTap: () => context.push(PastPhotosScreen.routePath),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Completed inspections are read-only.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: Theme.of(context).textTheme.headlineSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Every finding of the open (completed) inspection, grouped by area —
/// tap one for its read-only Finding Detail.
class PastFindingsScreen extends ConsumerWidget {
  const PastFindingsScreen({super.key});

  static const routePath = '/home-inspection/past-findings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Findings')),
        body: const AppEmptyView(
          icon: Icons.error_outline,
          title: 'No inspection open',
        ),
      );
    }
    final suggestions = activeSuggestionsOf(session);
    final catalogue = DefectCatalogue.instance;
    final groups = [
      for (final section in session.sections)
        (
          section,
          session.findings.where((f) => f.sectionId == section.id).toList(),
        ),
    ].where((g) => g.$2.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Findings')),
      body: groups.isEmpty
          ? const AppEmptyView(
              icon: Icons.fact_check_outlined,
              title: 'No findings recorded',
              message: 'This inspection completed with no defects.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                for (final (section, findings) in groups) ...[
                  AppSectionHeader(title: section.name),
                  AppGroupedList(
                    children: [
                      for (final finding in findings)
                        Builder(
                          builder: (context) {
                            final suggestion = suggestions.firstWhereOrNull(
                              (s) => s.findingId == finding.id,
                            );
                            final entryId = suggestion?.hasFinalEntry == true
                                ? suggestion!.finalCatalogueEntryId
                                : suggestion?.suggestedCatalogueEntryId;
                            final entry = entryId == null
                                ? null
                                : catalogue.byId(entryId);
                            final (status, label) = findingStatusOf(
                              finding,
                              suggestion,
                            );
                            final photo = finding.evidence.firstOrNull;
                            return ListTile(
                              key: ValueKey('past-finding-${finding.id}'),
                              leading: _Thumb(photo: photo, size: 52),
                              title: Text(
                                entry?.defectDescription ??
                                    finding.defectNote ??
                                    'Finding',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: AppStatusChip(
                                    status: status,
                                    label: label,
                                  ),
                                ),
                              ),
                              onTap: () => context.push(
                                findingDetailLocation(finding.id),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.photo, this.size = 52});

  final Evidence? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = SizedBox(
      width: size,
      height: size,
      child: const ColoredBox(
        color: AppColors.surfaceMuted,
        child: Icon(Icons.photo_outlined, color: AppColors.textMuted),
      ),
    );
    if (photo == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.file(
          File(photo!.displayFilePath),
          fit: BoxFit.cover,
          cacheWidth: (size * 3).round(),
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}

/// Every photo of the open (completed) inspection. Shows the working
/// copy first (fast, on-device); "View Original" fetches the full
/// original from the inspector's Google Drive where it was backed up,
/// and falls back to the working copy if Drive can't provide it.
class PastPhotosScreen extends ConsumerWidget {
  const PastPhotosScreen({super.key});

  static const routePath = '/home-inspection/past-photos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Photos')),
        body: const AppEmptyView(
          icon: Icons.error_outline,
          title: 'No inspection open',
        ),
      );
    }
    final backups =
        ref.watch(sessionDriveBackupsProvider(session.id)).value ?? const {};
    final photos = [
      for (final section in session.sections)
        for (final finding in session.findings.where(
          (f) => f.sectionId == section.id,
        ))
          for (final evidence in finding.evidence) (section, finding, evidence),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('Photos (${photos.length})')),
      body: photos.isEmpty
          ? const AppEmptyView(
              icon: Icons.photo_library_outlined,
              title: 'No photos',
              message: 'This inspection has no finding photos.',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
              ),
              itemCount: photos.length,
              itemBuilder: (context, i) {
                final (section, _, evidence) = photos[i];
                final backedUp = backups[evidence.id]?.isVerified == true;
                return InkWell(
                  key: ValueKey('past-photo-${evidence.id}'),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PastPhotoViewer(
                        evidence: evidence,
                        areaName: section.name,
                        backup: backups[evidence.id],
                      ),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Image.file(
                          File(evidence.displayFilePath),
                          fit: BoxFit.cover,
                          cacheWidth: 480,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(
                                color: AppColors.surfaceMuted,
                                child: Icon(
                                  Icons.photo_outlined,
                                  color: AppColors.textMuted,
                                ),
                              ),
                        ),
                      ),
                      if (backedUp)
                        const Positioned(
                          right: 6,
                          bottom: 6,
                          child: Icon(
                            Icons.cloud_done,
                            color: Colors.white,
                            size: 20,
                            semanticLabel: 'Backed up to Google Drive',
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// One historical photo, read-only (no markup, no removal), with "View
/// Original" from Google Drive.
class PastPhotoViewer extends ConsumerStatefulWidget {
  const PastPhotoViewer({
    super.key,
    required this.evidence,
    required this.areaName,
    required this.backup,
  });

  final Evidence evidence;
  final String areaName;
  final DriveBackupEntry? backup;

  @override
  ConsumerState<PastPhotoViewer> createState() => _PastPhotoViewerState();
}

class _PastPhotoViewerState extends ConsumerState<PastPhotoViewer> {
  Uint8List? _original;
  bool _loading = false;

  Future<void> _viewOriginal() async {
    setState(() => _loading = true);
    final bytes = await ref
        .read(driveBackupCoordinatorProvider)
        .downloadOriginal(widget.evidence.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (bytes != null) _original = Uint8List.fromList(bytes);
    });
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "The Drive original isn't available right now — showing the "
            'copy on this device.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canViewOriginal = widget.backup?.isVerified == true;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_original == null ? widget.areaName : 'Original'),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: _original != null
              ? Image.memory(_original!, fit: BoxFit.contain)
              : Image.file(
                  File(widget.evidence.displayFilePath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Text(
                    'This photo is not on this device.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _original != null
              ? const Text(
                  'Full-resolution original from your Google Drive.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                )
              : FilledButton.icon(
                  key: const ValueKey('view-original'),
                  onPressed: canViewOriginal && !_loading
                      ? _viewOriginal
                      : null,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_to_drive),
                  label: Text(
                    canViewOriginal
                        ? 'View Original'
                        : 'Original not backed up to Drive yet',
                  ),
                ),
        ),
      ),
    );
  }
}
