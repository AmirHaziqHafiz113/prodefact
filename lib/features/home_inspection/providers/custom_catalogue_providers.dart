import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../core/logging/app_logger.dart';
import '../../../data/local/database_providers.dart';
import '../../../data/remote/remote_providers.dart';

/// The signed-in account's own custom defect catalogue (entries its
/// company added because the ProDefact master catalogue lacked them).
///
/// - Scoped by account: the entries loaded are only ever those of the
///   current uid, and the shared [DefectCatalogue] overlay is cleared
///   whenever there is no signed-in account (or a different one), so one
///   company's entries are never visible to another.
/// - The local database is authoritative; cloud (`users/{uid}/
///   customCatalogue`) is a mirror that also restores a fresh device.
/// - Never touches the master catalogue, and is never sent to AI (the AI
///   shortlist is master-only — see docs/custom_catalogue.md).
final customCatalogueProvider =
    AsyncNotifierProvider<CustomCatalogueNotifier, List<CustomDefect>>(
      CustomCatalogueNotifier.new,
    );

/// The uid custom entries are stored under in local-only builds, where no
/// account exists.
const kLocalCatalogueOwner = 'local';

class AddCustomDefectResult {
  const AddCustomDefectResult({this.entry, this.validation});

  /// Set when the entry was saved and is immediately selectable.
  final DefectCatalogueEntry? entry;
  final CustomDefectValidation? validation;

  bool get saved => entry != null;
}

class CustomCatalogueNotifier extends AsyncNotifier<List<CustomDefect>> {
  String? _ownerUid() {
    if (!ref.read(firebaseReadyProvider)) return kLocalCatalogueOwner;
    return ref.read(authServiceProvider).currentUser?.uid;
  }

  @override
  Future<List<CustomDefect>> build() async {
    final firebaseReady = ref.watch(firebaseReadyProvider);
    // Re-runs on every sign-in / sign-out / account switch (and when
    // Firebase Auth finishes restoring the user), so a restoring session
    // is corrected as soon as the auth stream speaks.
    if (firebaseReady) ref.watch(authStateProvider);
    final owner = firebaseReady
        ? ref.read(authServiceProvider).currentUser?.uid
        : kLocalCatalogueOwner;
    if (owner == null) {
      DefectCatalogue.instance.replaceCustomEntries(const []);
      return const [];
    }
    final repository = ref.read(inspectionRepositoryProvider);
    var local = await repository.loadCustomDefects(owner);
    _register(local);
    if (firebaseReady) {
      try {
        final cloud = ref.read(cloudInspectionRepositoryProvider);
        final remote = await cloud.fetchCustomDefects(owner);
        final localIds = {for (final d in local) d.id};
        final remoteIds = {for (final d in remote) d.id};
        for (final d in remote) {
          if (!localIds.contains(d.id)) await repository.saveCustomDefect(d);
        }
        for (final d in local) {
          if (!remoteIds.contains(d.id)) await cloud.pushCustomDefect(owner, d);
        }
        local = await repository.loadCustomDefects(owner);
        _register(local);
      } catch (error) {
        // Offline/unavailable: the local copy keeps working; the next
        // load (sign-in, app start) reconciles.
        AppLogger.warning('Custom catalogue cloud sync skipped', error);
      }
    }
    return local;
  }

  void _register(List<CustomDefect> defects) {
    DefectCatalogue.instance.replaceCustomEntries([
      for (final d in defects)
        if (!d.archived) d.toEntry(),
    ]);
  }

  /// Validates and saves a new custom defect. Returns the validation
  /// problem (nothing saved) or the new, immediately selectable entry.
  Future<AddCustomDefectResult> add({
    required String element,
    required String component,
    required String description,
    required String correctiveAction,
    String? note,
  }) async {
    final owner = _ownerUid();
    final catalogue = DefectCatalogue.instance;
    final validation = validateCustomDefect(
      element: element,
      component: component,
      description: description,
      correctiveAction: correctiveAction,
      note: note,
      existing: catalogue.entries,
    );
    if (owner == null || !validation.isValid) {
      return AddCustomDefectResult(validation: validation);
    }
    final ids = resolveCustomIds(
      element: validation.element!,
      component: validation.component!,
      existing: catalogue.entries,
    );
    final now = DateTime.now();
    final defect = CustomDefect(
      id: 'custom.${now.microsecondsSinceEpoch}',
      ownerUid: owner,
      elementId: ids.elementId,
      elementName: validation.element!,
      componentId: ids.componentId,
      componentName: validation.component!,
      defectDescription: validation.description!,
      correctiveAction: validation.correctiveAction!,
      note: validation.note,
      createdAt: now,
    );
    await ref.read(inspectionRepositoryProvider).saveCustomDefect(defect);
    final updated = [...?state.value, defect];
    _register(updated);
    state = AsyncData(updated);
    if (ref.read(firebaseReadyProvider)) {
      unawaited(
        ref
            .read(cloudInspectionRepositoryProvider)
            .pushCustomDefect(owner, defect)
            .catchError(
              (Object e) =>
                  AppLogger.warning('Could not push custom defect', e),
            ),
      );
    }
    return AddCustomDefectResult(
      entry: defect.toEntry(),
      validation: validation,
    );
  }

  /// Archives (hides from search/selection) a custom defect. Findings
  /// that already use it keep their wording in existing inspections.
  Future<void> archive(String id) async {
    final owner = _ownerUid();
    final current = state.value ?? const [];
    final target = current.where((d) => d.id == id).firstOrNull;
    if (owner == null || target == null) return;
    final archived = target.copyWith(archived: true);
    await ref.read(inspectionRepositoryProvider).saveCustomDefect(archived);
    final updated = [for (final d in current) d.id == id ? archived : d];
    _register(updated);
    state = AsyncData(updated);
    if (ref.read(firebaseReadyProvider)) {
      unawaited(
        ref
            .read(cloudInspectionRepositoryProvider)
            .pushCustomDefect(owner, archived)
            .catchError(
              (Object e) =>
                  AppLogger.warning('Could not push custom defect', e),
            ),
      );
    }
  }
}
