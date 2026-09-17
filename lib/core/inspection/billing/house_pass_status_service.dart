import 'house_pass_summary.dart';

/// Read-only access to one inspection's House Pass lifecycle — the
/// House Pass screen's counterpart to `WalletActivityService`. Backend
/// remains authoritative throughout: this only ever reads
/// already-written Firestore state (owner-read-only, never
/// client-writable — see `firestore.rules`); nothing here decides or
/// infers a pass's status itself.
abstract class HousePassStatusService {
  Future<HousePassSummary> loadHousePassStatus(String uid, String inspectionId);
}
