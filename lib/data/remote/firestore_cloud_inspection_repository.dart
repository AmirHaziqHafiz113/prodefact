import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_storage/firebase_storage.dart' as storage;

import '../../core/inspection/inspection_domain.dart';

/// Firestore + Storage implementation of [CloudInspectionRepository].
///
/// Firestore layout (see `docs/firebase.md` for the full model):
///   users/{uid}/inspections/{sessionId}
///     /sections/{sectionId}
///     /findings/{findingId}
///       /evidence/{evidenceId}
///     /aiSuggestions/{suggestionId}
///
/// Storage layout:
///   users/{uid}/inspections/{sessionId}/findings/{findingId}/{evidenceId}.jpg
///
/// This is the only file that imports `cloud_firestore`/
/// `firebase_storage` — everything else depends on the abstract
/// [CloudInspectionRepository] interface, so no Firebase SDK type leaks
/// past this boundary.
class FirestoreCloudInspectionRepository implements CloudInspectionRepository {
  FirestoreCloudInspectionRepository({
    fs.FirebaseFirestore? firestore,
    storage.FirebaseStorage? storageInstance,
  }) : _firestore = firestore ?? fs.FirebaseFirestore.instance,
       _storage = storageInstance ?? storage.FirebaseStorage.instance;

  final fs.FirebaseFirestore _firestore;
  final storage.FirebaseStorage _storage;

  fs.DocumentReference<Map<String, dynamic>> _sessionDoc(
    String ownerUid,
    String sessionId,
  ) => _firestore
      .collection('users')
      .doc(ownerUid)
      .collection('inspections')
      .doc(sessionId);

  @override
  Future<void> pushSession(String ownerUid, InspectionSession session) {
    return _sessionDoc(ownerUid, session.id).set({
      'industry': session.industry.name,
      'assetTypeId': session.assetTypeId,
      'status': session.status.name,
      'createdAt': fs.Timestamp.fromDate(session.createdAt),
      'updatedAt': fs.Timestamp.fromDate(session.updatedAt),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> pushSections(
    String ownerUid,
    String sessionId,
    List<Section> sections,
  ) async {
    final sectionsCollection = _sessionDoc(
      ownerUid,
      sessionId,
    ).collection('sections');

    final existing = await sectionsCollection.get();
    final keepIds = sections.map((s) => s.id).toSet();

    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      if (!keepIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      batch.set(sectionsCollection.doc(section.id), {
        'name': section.name,
        'isPlumbing': section.isPlumbing,
        'isIncluded': section.isIncluded,
        'orderIndex': i,
        'elements': section.elements
            .map(
              (element) => {
                'id': element.id,
                'name': element.name,
                'components': element.components
                    .map((c) => {'id': c.id, 'name': c.name})
                    .toList(),
              },
            )
            .toList(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> pushFinding(String ownerUid, String sessionId, Finding finding) {
    return _sessionDoc(
      ownerUid,
      sessionId,
    ).collection('findings').doc(finding.id).set({
      'sectionId': finding.sectionId,
      'elementId': finding.elementId,
      'componentId': finding.componentId,
      'description': finding.description,
      'notes': finding.notes,
      'status': finding.status.name,
      'createdAt': fs.Timestamp.fromDate(finding.createdAt),
      'updatedAt': fs.Timestamp.fromDate(finding.updatedAt),
    }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteFinding(
    String ownerUid,
    String sessionId,
    String findingId,
  ) async {
    final findingDoc = _sessionDoc(
      ownerUid,
      sessionId,
    ).collection('findings').doc(findingId);
    final evidence = await findingDoc.collection('evidence').get();
    final batch = _firestore.batch();
    for (final doc in evidence.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(findingDoc);
    await batch.commit();
  }

  String _storagePathFor(
    String ownerUid,
    String sessionId,
    String findingId,
    String evidenceId,
  ) =>
      'users/$ownerUid/inspections/$sessionId/findings/$findingId/$evidenceId.jpg';

  @override
  Future<String> uploadEvidenceFile(
    String ownerUid,
    String sessionId,
    Evidence evidence,
  ) async {
    final path = _storagePathFor(
      ownerUid,
      sessionId,
      evidence.findingId,
      evidence.id,
    );
    final file = File(evidence.filePath);
    if (!file.existsSync()) {
      throw StateError(
        'Local evidence file is missing, cannot upload: ${evidence.filePath}',
      );
    }
    await _storage.ref(path).putFile(file);
    return path;
  }

  @override
  Future<void> pushEvidenceMetadata(
    String ownerUid,
    String sessionId,
    Evidence evidence,
  ) {
    return _sessionDoc(ownerUid, sessionId)
        .collection('findings')
        .doc(evidence.findingId)
        .collection('evidence')
        .doc(evidence.id)
        .set({
          'mediaType': evidence.mediaType.name,
          'source': evidence.source.name,
          'caption': evidence.caption,
          'storagePath': evidence.storagePath,
          'createdAt': fs.Timestamp.fromDate(evidence.createdAt),
        }, fs.SetOptions(merge: true));
  }

  @override
  Future<void> deleteEvidence(
    String ownerUid,
    String sessionId,
    String findingId,
    String evidenceId,
  ) async {
    await _sessionDoc(ownerUid, sessionId)
        .collection('findings')
        .doc(findingId)
        .collection('evidence')
        .doc(evidenceId)
        .delete();
    await _storage
        .ref(_storagePathFor(ownerUid, sessionId, findingId, evidenceId))
        .delete()
        .catchError((Object _) {
          // Nothing to remove remotely — not an error worth failing sync
          // over (e.g. it was never uploaded in the first place).
        });
  }

  @override
  Future<void> pushAiSuggestion(
    String ownerUid,
    String sessionId,
    AiSuggestion suggestion,
  ) {
    return _sessionDoc(
      ownerUid,
      sessionId,
    ).collection('aiSuggestions').doc(suggestion.id).set({
      'findingId': suggestion.findingId,
      'providerId': suggestion.providerId,
      'generatedAt': fs.Timestamp.fromDate(suggestion.generatedAt),
      'suggestedElementId': suggestion.suggestedElementId,
      'suggestedComponentId': suggestion.suggestedComponentId,
      'suggestedDefectType': suggestion.suggestedDefectType,
      'suggestedRecommendation': suggestion.suggestedRecommendation,
      'suggestedNotes': suggestion.suggestedNotes,
      'finalElementId': suggestion.finalElementId,
      'finalComponentId': suggestion.finalComponentId,
      'finalDefectType': suggestion.finalDefectType,
      'finalRecommendation': suggestion.finalRecommendation,
      'finalNotes': suggestion.finalNotes,
      'status': suggestion.status.name,
      'reviewedAt': suggestion.reviewedAt == null
          ? null
          : fs.Timestamp.fromDate(suggestion.reviewedAt!),
    }, fs.SetOptions(merge: true));
  }
}
