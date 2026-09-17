import Foundation
import Testing

@testable import SwiftACD
@testable import SwiftACD_E2E

@Suite
struct `Distribution report` {

  // MARK: - Fixture factories

  /// A profile carrying only the fields a test names, so coverage counts read
  /// as "how many profiles have this" rather than "what does the fixture set".
  static func profile(
    ICAO: String,
    manufacturer: String? = nil,
    wingspanWithWinglets: Double? = nil,
    machClimb: Performance.MachClimbBand? = nil,
    variants: [Variant] = [],
    sources: Source = .APD
  ) -> AircraftProfile {
    AircraftProfile(
      identity: Identity(ICAOTypeDesignator: ICAO, manufacturer: manufacturer),
      categories: Categories(),
      dimensions: Dimensions(
        wingspanFt: 100,
        lengthFt: 100,
        tailHeightFt: 20,
        wingspanWithWingletsFt: wingspanWithWinglets
      ),
      weights: nil,
      recognition: nil,
      performance: machClimb.map { .init(climb: Performance.Climb(machClimb: $0)) },
      variants: variants,
      sources: sources
    )
  }

  static func report(
    _ profiles: [AircraftProfile],
    errorCount: Int = 0,
    errorSamples: [String] = []
  ) throws -> DistributionReport {
    try DistributionReport(
      profiles: Dictionary(
        uniqueKeysWithValues: profiles.map { ($0.identity.ICAOTypeDesignator, $0) }
      ),
      errorCount: errorCount,
      errorSamples: errorSamples
    )
  }

  // MARK: - Coverage

  @Test
  func `counts the profiles carrying each field rather than the profiles`() throws {
    let report = try Self.report([
      Self.profile(ICAO: "A320", manufacturer: "Airbus", wingspanWithWinglets: 117.5),
      Self.profile(ICAO: "B738", manufacturer: "Boeing"),
      Self.profile(ICAO: "C172")
    ])

    #expect(report.profileCount == 3)
    #expect(report.coverage["dimensions.lengthFt"] == 3)
    #expect(report.coverage["identity.manufacturer"] == 2)
    #expect(report.coverage["dimensions.wingspanWithWingletsFt"] == 1)
    // A field no profile carries is absent, not zero — it is indistinguishable
    // from a field the model never had.
    #expect(report.coverage["weights.MTOWLb"] == nil)
  }

  @Test
  func `folds array elements into the array's own key path`() throws {
    let variant = Variant(
      id: "B738#0",
      manufacturer: "Boeing",
      model: "737-800",
      approachSpeedKt: nil,
      dimensions: nil,
      weights: nil,
      categories: Categories()
    )
    let report = try Self.report([
      Self.profile(ICAO: "B738", variants: [variant, variant]),
      Self.profile(ICAO: "C172")
    ])

    // Two variants on one profile still count once: coverage measures profiles.
    #expect(report.coverage["variants"] == 1)
    #expect(report.coverage["variants.model"] == 1)
  }

  @Test
  func `tallies profiles by the sources that built them`() throws {
    let report = try Self.report([
      Self.profile(ICAO: "A320", sources: [.ACD, .APD]),
      Self.profile(ICAO: "B738", sources: .ACD),
      Self.profile(ICAO: "C172", sources: .ACD)
    ])

    #expect(report.sources == ["both": 1, "ACD": 2, "APD": 0])
  }

  @Test
  func `fails a run that reported per-record errors`() throws {
    let report = try Self.report([Self.profile(ICAO: "A320")], errorCount: 2)

    #expect(report.failed)
    #expect(report.failureReasons.count == 1)
  }

  // MARK: - Baseline comparison

  @Test
  func `fails when a field the baseline carried has emptied`() throws {
    let baseline = try Self.report([
      Self.profile(ICAO: "A320", manufacturer: "Airbus"),
      Self.profile(ICAO: "B738", manufacturer: "Boeing")
    ])
    var current = try Self.report([
      Self.profile(ICAO: "A320"),
      Self.profile(ICAO: "B738")
    ])
    current.compare(against: baseline)

    #expect(current.failed)
    #expect(current.drift.contains { $0.field == "identity.manufacturer" && $0.now == 0 })
  }

  @Test
  func `reports a sharp coverage drop as drift without failing the run`() throws {
    let baseline = try Self.report(
      (1...10).map { Self.profile(ICAO: "X\($0)", manufacturer: "Airbus") }
    )
    var current = try Self.report(
      (1...10).map { Self.profile(ICAO: "X\($0)", manufacturer: $0 > 5 ? nil : "Airbus") }
    )
    current.compare(against: baseline)

    #expect(!current.failed)
    #expect(current.drift.contains { $0.field == "identity.manufacturer" && $0.now == 5 })
  }

  @Test
  func `ignores a coverage change the sources could plausibly have made`() throws {
    let baseline = try Self.report(
      (1...10).map { Self.profile(ICAO: "X\($0)", manufacturer: "Airbus") }
    )
    var current = try Self.report(
      (1...10).map { Self.profile(ICAO: "X\($0)", manufacturer: $0 > 9 ? nil : "Airbus") }
    )
    current.compare(against: baseline)

    #expect(!current.failed)
    #expect(current.drift.isEmpty)
  }

  @Test
  func `treats a field the baseline never saw as new coverage`() throws {
    let baseline = try Self.report([Self.profile(ICAO: "A320")])
    var current = try Self.report([Self.profile(ICAO: "A320", wingspanWithWinglets: 117.5)])
    current.compare(against: baseline)

    #expect(!current.failed)
    #expect(current.drift.isEmpty)
  }

  @Test
  func `fails when the distribution loses profiles`() throws {
    let baseline = try Self.report((1...100).map { Self.profile(ICAO: "X\($0)") })
    var current = try Self.report((1...90).map { Self.profile(ICAO: "X\($0)") })
    current.compare(against: baseline)

    #expect(current.failed)
    #expect(current.drift.contains { $0.field == "profileCount" })
  }

  @Test
  func `round-trips through JSON so a report can be read back as a baseline`() throws {
    var report = try Self.report([Self.profile(ICAO: "A320", manufacturer: "Airbus")])
    report.compare(against: try Self.report([Self.profile(ICAO: "A320", manufacturer: "Airbus")]))

    let decoded = try JSONDecoder().decode(
      DistributionReport.self,
      from: try JSONEncoder().encode(report)
    )

    #expect(decoded.coverage == report.coverage)
    #expect(decoded.profileCount == report.profileCount)
    #expect(decoded.failed == report.failed)
  }
}
