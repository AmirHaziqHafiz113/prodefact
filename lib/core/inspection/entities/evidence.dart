/// A piece of evidence (currently just a photo) captured for a [Finding]
/// during the physical inspection.
///
/// Deliberately storage-agnostic: capturing and persisting evidence
/// (camera, file storage) is out of scope for the foundation phase.
class Evidence {
  const Evidence({required this.id, required this.filePath});

  final String id;
  final String filePath;

  @override
  String toString() => 'Evidence($id, $filePath)';
}
