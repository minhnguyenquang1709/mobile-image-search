/// The phase a "move to album" operation is in.
enum MoveState {
  idle,

  /// copying files into the album folder (one file at a time)
  copying,

  /// copies done, waiting for the user to confirm deleting the originals
  awaitingConsent,

  /// originals deleted, move finished successfully
  done,

  /// user denied the delete consent (copies were rolled back)
  denied,

  /// the move failed
  error,
}

/// Progress of a "move images & videos to album" operation.
///
/// A small immutable snapshot the repository emits
/// as the move advances, which the ViewModel exposes to the UI.
class MoveProgress {
  final int total;
  final int processed;
  final bool isMoving;
  final String? currentAssetId;
  final MoveState state;

  MoveProgress({
    required this.total,
    required this.processed,
    required this.isMoving,
    required this.state,
    this.currentAssetId,
  });

  factory MoveProgress.idle() => MoveProgress(
    total: 0,
    processed: 0,
    isMoving: false,
    state: MoveState.idle,
  );

  double get progress => total == 0 ? 0 : processed / total;

  MoveProgress copyWith({
    int? total,
    int? processed,
    bool? isMoving,
    String? currentAssetId,
    MoveState? state,
  }) {
    return MoveProgress(
      total: total ?? this.total,
      processed: processed ?? this.processed,
      isMoving: isMoving ?? this.isMoving,
      currentAssetId: currentAssetId ?? this.currentAssetId,
      state: state ?? this.state,
    );
  }
}
