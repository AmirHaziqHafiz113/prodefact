/// Hands a generated report off to the platform's share sheet.
///
/// Kept behind this abstraction so UI/providers never depend on a
/// specific share package directly, and so tests can substitute a fake
/// instead of driving a real OS share sheet.
abstract class ReportShareService {
  Future<void> shareReport({
    required String filePath,
    required String fileName,
  });
}
