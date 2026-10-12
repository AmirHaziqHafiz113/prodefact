import 'dart:async';
import 'dart:collection';

/// How many findings may upload + classify at the same time. One photo =
/// one finding = one upload and one AI job, so a 12- or 100-photo gallery
/// selection must not start 100 uploads and AI calls at once: the rest wait
/// (staying `queued`) and start as earlier ones finish. Three keeps a phone
/// connection busy without starving anything, and an inspector can keep
/// working meanwhile — nothing here ever blocks the UI.
const int kMaxConcurrentFindingJobs = 3;

/// A tiny FIFO counting semaphore bounding concurrent finding jobs.
class FindingJobGate {
  FindingJobGate({this.maxConcurrent = kMaxConcurrentFindingJobs})
    : assert(maxConcurrent > 0);

  final int maxConcurrent;
  int _active = 0;
  final Queue<Completer<void>> _waiting = Queue();

  /// Jobs running right now.
  int get active => _active;

  /// Jobs waiting for a slot.
  int get waiting => _waiting.length;

  /// Completes when a slot is free (immediately if one is). Every
  /// successful [acquire] must be paired with exactly one [release].
  Future<void> acquire() {
    if (_active < maxConcurrent) {
      _active++;
      return Future.value();
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    return waiter.future;
  }

  /// Frees a slot, handing it straight to the longest-waiting job.
  void release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete(); // slot passes on, _active unchanged
      return;
    }
    if (_active > 0) _active--;
  }
}
