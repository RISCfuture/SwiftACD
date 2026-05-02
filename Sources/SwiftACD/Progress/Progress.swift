import Foundation

/// Snapshot of the progress of a parse operation.
public struct Progress: Sendable {

  /// The number of units already parsed (typically bytes).
  public let completed: Int64

  /// The total number of units to be parsed.
  public let total: Int64

  /// `true` when ``completed`` and ``total`` are equal.
  public var isFinished: Bool { completed == total }

  /// Ratio of completed to total operations (0.0 – 1.0).
  public var fractionDone: Double {
    guard total != 0 else { return 0 }
    return Double(completed) / Double(total)
  }

  /// The ``fractionDone`` expressed as a percentage (0 – 100).
  public var percentDone: Double { fractionDone * 100 }

  init(_ completed: Int64, of total: Int64) {
    self.completed = completed
    self.total = total
  }
}
