import Foundation

/// Callback invoked when ``AsyncProgress``'s `completed` or `total` changes.
public typealias ProgressCallback = @Sendable (Progress) -> Void

/// Tracker for the progress of a long-running parse.
///
/// Pass an instance to ``Parser/parse(progress:errorCallback:)`` and either
/// poll its properties or supply a ``callback`` to react to updates.
///
/// Example:
///
/// ```swift
/// let progress = AsyncProgress()
/// Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
///   Task { print("Progress: \(await progress.percentDone ?? 0)%") }
/// }
/// _ = try await parser.parse(progress: progress, errorCallback: { _ in })
/// ```
public actor AsyncProgress {
  private var totalBytes: Int64 = 0 {
    didSet {
      guard totalBytes != oldValue, let callback else { return }
      callback(progress)
    }
  }

  private var completedBytes: Int64 = 0 {
    didSet {
      guard completedBytes != oldValue, let callback else { return }
      callback(progress)
    }
  }

  /// Optional callback invoked any time `completed` or `total` changes.
  public var callback: ProgressCallback?

  /// The expected total number of bytes to parse.
  public var total: Int64 { totalBytes }

  /// Bytes parsed so far.
  public var completed: Int64 { completedBytes }

  /// `true` when the operation is finished.
  public var isFinished: Bool { completed == total }

  /// `true` when the total is unknown.
  public var isIndeterminate: Bool { total == 0 }

  /// Snapshot of the current progress.
  public var progress: Progress { .init(completed, of: total) }

  /// Ratio of completed to total bytes (0.0 – 1.0). `nil` when indeterminate.
  public var fractionDone: Double? {
    guard total != 0 else { return nil }
    return Double(completed) / Double(total)
  }

  /// The ``fractionDone`` expressed as a percentage. `nil` when indeterminate.
  public var percentDone: Double? {
    guard let fractionDone else { return nil }
    return fractionDone * 100
  }

  /// Creates a new tracker.
  ///
  /// - Parameter callback: Optional callback invoked any time `completed` or
  ///   `total` changes. Pass `nil` to poll the actor's properties instead.
  public init(callback: ProgressCallback? = nil) {
    self.callback = callback
  }

  func setTotalBytes(_ bytes: Int64) {
    totalBytes = bytes
  }

  func addBytes(_ bytes: Int64) {
    completedBytes = min(completedBytes + bytes, totalBytes)
  }
}
