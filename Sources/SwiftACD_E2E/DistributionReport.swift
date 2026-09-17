import Foundation
import SwiftACD

// A parse that drops a field reports no error at all — the parsers skip what
// they cannot read and carry on — so an error count alone cannot tell a clean
// run from a silent regression. The report therefore records how many profiles
// carry each field, and the next run compares against it.
struct DistributionReport: Codable, Sendable {

  // A field that empties entirely is a parser regression; one that merely
  // thins out is usually the sources editing their data.
  private static let coverageDropTolerance = 0.25

  // Profiles come and go as the FAA revises the workbook, but the total does
  // not fall far without something having gone wrong.
  private static let profileCountTolerance = 0.05

  private static let maximumErrorSamples = 50

  let profileCount: Int

  let errorCount: Int

  /// Localized failure reasons for the first ``maximumErrorSamples`` errors.
  let errorSamples: [String]

  /// Profile counts keyed by lineage: `ACD`, `APD`, and `both`.
  let sources: [String: Int]

  /// Number of profiles carrying a value for each encoded key path, e.g.
  /// `performance.descent.initialDescent` → `244`.
  let coverage: [String: Int]

  /// Fields that lost ground against the baseline. Empty without a baseline.
  private(set) var drift: [Drift] = []

  private(set) var failed: Bool

  private(set) var failureReasons: [String] = []

  init(
    profiles: [String: AircraftProfile],
    errorCount: Int,
    errorSamples: [String]
  ) throws {
    profileCount = profiles.count
    self.errorCount = errorCount
    self.errorSamples = Array(errorSamples.prefix(Self.maximumErrorSamples))
    sources = Self.sourceCounts(of: profiles)
    coverage = try Self.coverageCounts(of: profiles)
    failed = errorCount > 0
    if errorCount > 0 {
      failureReasons.append("the parse reported \(errorCount) per-record error(s)")
    }
  }

  // MARK: - Coverage

  private static func sourceCounts(of profiles: [String: AircraftProfile]) -> [String: Int] {
    var counts = ["ACD": 0, "APD": 0, "both": 0]
    for profile in profiles.values {
      switch (profile.sources.contains(.ACD), profile.sources.contains(.APD)) {
        case (true, true): counts["both"]? += 1
        case (true, false): counts["ACD"]? += 1
        case (false, true): counts["APD"]? += 1
        case (false, false): continue
      }
    }
    return counts
  }

  // Counting is driven by each profile's encoded form rather than by a list of
  // key paths, so a field added to the model is covered without being named
  // here. `Codable` omits a `nil` property, which is exactly the "no value"
  // this counts.
  private static func coverageCounts(of profiles: [String: AircraftProfile]) throws -> [String: Int]
  {
    let encoder = JSONEncoder()
    var counts: [String: Int] = [:]
    for profile in profiles.values {
      let encoded = try JSONSerialization.jsonObject(with: try encoder.encode(profile))
      var fields: Set<String> = []
      collectFields(from: encoded, at: "", into: &fields)
      for field in fields { counts[field, default: 0] += 1 }
    }
    return counts
  }

  // Array elements fold into their parent's path, so `variants.model` counts
  // the profiles with a named variant rather than the variants themselves.
  private static func collectFields(
    from value: Any,
    at path: String,
    into fields: inout Set<String>
  ) {
    switch value {
      case is NSNull:
        return
      case let object as [String: Any]:
        for (key, child) in object {
          collectFields(from: child, at: path.isEmpty ? key : "\(path).\(key)", into: &fields)
        }
      case let array as [Any]:
        guard !array.isEmpty else { return }
        fields.insert(path)
        for element in array {
          collectFields(from: element, at: path, into: &fields)
        }
      default:
        fields.insert(path)
    }
  }

  // MARK: - Baseline comparison

  /// Record how this run compares with the previous one. A field the baseline
  /// never saw is new coverage, not drift.
  mutating func compare(against baseline: Self) {
    for (field, was) in baseline.coverage.sorted(by: { $0.key < $1.key }) where was > 0 {
      let now = coverage[field] ?? 0
      if now == 0 {
        drift.append(
          .init(field: field, was: was, now: now, reason: "no profile carries this field any more")
        )
        failureReasons.append("\(field) lost all \(was) value(s)")
      } else if droppedSteeply(from: was, to: now, tolerance: Self.coverageDropTolerance) {
        drift.append(.init(field: field, was: was, now: now, reason: "coverage fell sharply"))
      }
    }

    if droppedSteeply(
      from: baseline.profileCount,
      to: profileCount,
      tolerance: Self.profileCountTolerance
    ) {
      drift.append(
        .init(
          field: "profileCount",
          was: baseline.profileCount,
          now: profileCount,
          reason: "the distribution lost profiles"
        )
      )
      failureReasons.append(
        "profile count fell from \(baseline.profileCount) to \(profileCount)"
      )
    }

    failed = !failureReasons.isEmpty
  }

  private func droppedSteeply(from was: Int, to now: Int, tolerance: Double) -> Bool {
    guard was > 0, now < was else { return false }
    return Double(was - now) / Double(was) > tolerance
  }

  /// One field that lost ground between two runs.
  struct Drift: Codable, Sendable {
    let field: String
    let was: Int
    let now: Int
    let reason: String
  }
}
