import Foundation
import Testing

@testable import SwiftACD

@Suite("Builder")
struct BuilderTests {

  // MARK: - Fixture factories

  /// A reasonably complete ACD row for an A320, mirroring what the real
  /// workbook publishes.
  static func a320ACDRow(
    rowNumber: Int = 12,
    ICAO: String = "A320",
    model: String = "A320",
    MTOW: Double? = 169_755,
    wingspan: Double? = 111.8,
    length: Double? = 123.3,
    tailHeight: Double? = 38.6,
    mainGearWidth: Double? = 24.6,
    cockpitToMainGear: Double? = 41.7,
    approachSpeed: Double? = 138
  ) -> ACDRow {
    ACDRow(
      rowNumber: rowNumber,
      ICAOTypeDesignator: ICAO,
      manufacturer: "Airbus",
      model: model,
      approachCategory: .c,
      designGroup: .III,
      taxiwayDesignGroup: .group3,
      MTOWLb: MTOW,
      mainGearWidthFt: mainGearWidth,
      cockpitToMainGearFt: cockpitToMainGear,
      wingspanFt: wingspan,
      lengthFt: length,
      tailHeightFt: tailHeight,
      approachSpeedKt: approachSpeed
    )
  }

  /// A B738 ACD row keyed for variant fan-out testing.
  static func b738ACDRow(
    rowNumber: Int,
    model: String,
    MTOW: Double = 174_700
  ) -> ACDRow {
    ACDRow(
      rowNumber: rowNumber,
      ICAOTypeDesignator: "B738",
      manufacturer: "Boeing",
      model: model,
      approachCategory: .c,
      designGroup: .III,
      taxiwayDesignGroup: .group3,
      MTOWLb: MTOW,
      mainGearWidthFt: 18.9,
      cockpitToMainGearFt: 53.0,
      wingspanFt: 117.5,
      lengthFt: 129.5,
      tailHeightFt: 41.2,
      approachSpeedKt: 142
    )
  }

  /// An APDRecord populated with every field group, modelled on EUROCONTROL's
  /// A320 page.
  static func a320APDRecord(
    ICAO: String = "A320",
    MTOW: Double? = 162_929,
    wingspan: Double? = 111.85,
    length: Double? = 123.27,
    height: Double? = 38.62
  ) -> APDRecord {
    APDRecord(
      ICAOTypeDesignator: ICAO,
      identity: APDRecord.Identity(
        manufacturer: "Airbus",
        model: "A-320",
        IATACodes: ["320"],
        alternativeNames: ["NEO"],
        aircraftClass: .landplane,
        engineCount: .number(2),
        engineType: .jet
      ),
      categories: APDRecord.Categories(
        approachCategory: .c,
        wakeTurbulence: .medium,
        RECAT_EU: .upperMedium
      ),
      recognition: APDRecord.Recognition(
        wing: "Low wing",
        engine: "Underwing mounted",
        tail: "Regular tail, low set",
        landingGear: "Tricycle retractable"
      ),
      dimensions: APDRecord.Dimensions(
        wingspanFt: wingspan,
        lengthFt: length,
        heightFt: height
      ),
      weights: APDRecord.Weights(MTOWLb: MTOW),
      performance: APDRecord.Performance(
        takeoff: APDRecord.Performance.Takeoff(v2Kt: 145, distanceFt: 6_900),
        climb: APDRecord.Performance.Climb(
          initialIASKt: 175,
          initialRateOfClimbFPM: 2_500,
          to150IASKt: 290,
          to150RateOfClimbFPM: 2_000,
          to240IASKt: 290,
          to240RateOfClimbFPM: 1_000,
          machClimbMach: 0.78
        ),
        cruise: APDRecord.Performance.Cruise(
          TASKt: 447,
          mach: 0.78,
          ceilingFL: 391,
          rangeNmi: 3_300
        ),
        descent: APDRecord.Performance.Descent(
          initialIASKt: 290,
          initialRateOfDescentFPM: 3_500,
          descentIASKt: 290,
          descentRateOfDescentFPM: 2_000
        ),
        approach: APDRecord.Performance.Approach(
          IASKt: 250,
          minimumCleanSpeedKt: 210,
          rateOfDescentFPM: 1_000
        ),
        landing: APDRecord.Performance.Landing(vatKt: 138, distanceFt: 4_800)
      )
    )
  }

  /// An APD record with no dimensions, no recognition and only a takeoff
  /// phase populated, so we can exercise pruning.
  static func minimalAPDRecord(ICAO: String) -> APDRecord {
    APDRecord(
      ICAOTypeDesignator: ICAO,
      identity: APDRecord.Identity(
        manufacturer: nil,
        model: nil,
        IATACodes: [],
        alternativeNames: [],
        aircraftClass: nil,
        engineCount: nil,
        engineType: nil
      ),
      categories: APDRecord.Categories(
        approachCategory: nil,
        wakeTurbulence: nil,
        RECAT_EU: nil
      ),
      recognition: APDRecord.Recognition(
        wing: nil,
        engine: nil,
        tail: nil,
        landingGear: nil
      ),
      dimensions: APDRecord.Dimensions(wingspanFt: nil, lengthFt: nil, heightFt: nil),
      weights: APDRecord.Weights(MTOWLb: nil),
      performance: APDRecord.Performance(
        takeoff: APDRecord.Performance.Takeoff(v2Kt: 145, distanceFt: 6_900),
        climb: APDRecord.Performance.Climb(
          initialIASKt: nil,
          initialRateOfClimbFPM: nil,
          to150IASKt: nil,
          to150RateOfClimbFPM: nil,
          to240IASKt: nil,
          to240RateOfClimbFPM: nil,
          machClimbMach: nil
        ),
        cruise: APDRecord.Performance.Cruise(
          TASKt: nil,
          mach: nil,
          ceilingFL: nil,
          rangeNmi: nil
        ),
        descent: APDRecord.Performance.Descent(
          initialIASKt: nil,
          initialRateOfDescentFPM: nil,
          descentIASKt: nil,
          descentRateOfDescentFPM: nil
        ),
        approach: APDRecord.Performance.Approach(
          IASKt: nil,
          minimumCleanSpeedKt: nil,
          rateOfDescentFPM: nil
        ),
        landing: APDRecord.Performance.Landing(vatKt: nil, distanceFt: nil)
      )
    )
  }

  // MARK: - Tests

  @Test("ACD-only profile uses FAA fields, leaves APD-only fields nil")
  func acdOnlyProfile() throws {
    let row = Self.a320ACDRow()
    let result = Builder.build(ACDRows: [row], APDRecords: [:])

    let profile = try #require(result["A320"])
    #expect(profile.identity.ICAOTypeDesignator == "A320")
    #expect(profile.identity.manufacturer == "Airbus")
    #expect(profile.identity.model == "A320")
    #expect(profile.identity.IATACodes.isEmpty)
    #expect(profile.identity.alternativeNames.isEmpty)
    #expect(profile.identity.aircraftClass == nil)
    #expect(profile.identity.engineType == nil)

    #expect(profile.categories.approach == .c)
    #expect(profile.categories.designGroup == .III)
    #expect(profile.categories.taxiwayDesignGroup == .group3)
    #expect(profile.categories.wakeTurbulence == nil)
    #expect(profile.categories.RECAT_EU == nil)

    #expect(profile.recognition == nil)
    #expect(profile.performance == nil)
    #expect(profile.variants.count == 1)
    #expect(profile.sources == .ACD)
  }

  @Test("APD-only profile pulls identity, recognition, and performance from APD")
  func apdOnlyProfile() throws {
    let APD = Self.a320APDRecord(ICAO: "A20N")
    let result = Builder.build(ACDRows: [], APDRecords: ["A20N": APD])

    let profile = try #require(result["A20N"])
    #expect(profile.identity.ICAOTypeDesignator == "A20N")
    #expect(profile.identity.manufacturer == "Airbus")
    #expect(profile.identity.model == "A-320")
    #expect(profile.identity.IATACodes == ["320"])
    #expect(profile.identity.alternativeNames == ["NEO"])
    #expect(profile.identity.aircraftClass == .landplane)
    #expect(profile.identity.engineCount == .number(2))
    #expect(profile.identity.engineType == .jet)

    #expect(profile.categories.wakeTurbulence == .medium)
    #expect(profile.categories.RECAT_EU == .upperMedium)
    #expect(profile.categories.designGroup == nil)
    #expect(profile.categories.taxiwayDesignGroup == nil)

    #expect(profile.recognition != nil)
    #expect(profile.recognition?.wing == "Low wing")
    #expect(profile.recognition?.engine == "Underwing mounted")
    #expect(profile.recognition?.tail == "Regular tail, low set")
    #expect(profile.recognition?.landingGear == "Tricycle retractable")

    let performance = try #require(profile.performance)
    #expect(performance.takeoff?.v2Kt == 145)
    #expect(performance.cruise?.TASKt == 447)
    #expect(performance.landing?.vatKt == 138)

    #expect(profile.variants.isEmpty)
    #expect(profile.sources == .APD)
  }

  @Test("Overlap profile prefers FAA scalars and keeps APD-only fields")
  func overlapProfile() throws {
    let ACD = Self.a320ACDRow()
    let APD = Self.a320APDRecord()
    let result = Builder.build(ACDRows: [ACD], APDRecords: ["A320": APD])

    let profile = try #require(result["A320"])
    let weights = try #require(profile.weights)
    #expect(weights.MTOWLb == 169_755)
    #expect(weights.mainGearWidthFt == 24.6)
    #expect(weights.cockpitToMainGearFt == 41.7)

    let dims = try #require(profile.dimensions)
    #expect(dims.wingspanFt == 111.8)
    #expect(dims.lengthFt == 123.3)
    #expect(dims.tailHeightFt == 38.6)

    #expect(profile.categories.RECAT_EU == .upperMedium)
    #expect(profile.categories.wakeTurbulence == .medium)
    #expect(profile.categories.designGroup == .III)

    #expect(profile.identity.IATACodes == ["320"])
    #expect(profile.identity.aircraftClass == .landplane)

    #expect(profile.recognition != nil)
    #expect(profile.performance != nil)
    #expect(profile.sources == [.ACD, .APD])
  }

  @Test("Variant fan-out preserves every ACD row and exposes the first as the top-level model")
  func variantFanOut() throws {
    let row1 = Self.b738ACDRow(rowNumber: 1, model: "737-800")
    let row2 = Self.b738ACDRow(rowNumber: 2, model: "737-800W")
    let result = Builder.build(ACDRows: [row1, row2], APDRecords: [:])

    let profile = try #require(result["B738"])
    #expect(profile.variants.count == 2)
    #expect(profile.variants.contains { $0.model == "737-800" })
    #expect(profile.variants.contains { $0.model == "737-800W" })
    #expect(profile.variants.map(\.id) == ["B738#0", "B738#1"])
    #expect(profile.identity.model == profile.variants[0].model)
    #expect(profile.identity.model == "737-800")
  }

  @Test("Measurement computed properties surface the correct unit and value")
  func measurementVars() throws {
    let ACD = Self.a320ACDRow()
    let APD = Self.a320APDRecord()
    let result = Builder.build(ACDRows: [ACD], APDRecords: ["A320": APD])

    let profile = try #require(result["A320"])
    let dims = try #require(profile.dimensions)
    #expect(dims.wingspan.unit == .feet)
    #expect(dims.wingspan.value == 111.8)

    let weights = try #require(profile.weights)
    #expect(weights.MTOW.unit == .pounds)
    #expect(weights.MTOW.value == 169_755)

    let cruise = try #require(profile.performance?.cruise)
    let TAS = try #require(cruise.TAS)
    #expect(TAS.unit == .knots)
    #expect(TAS.value == 447)
  }

  @Test("All-nil dimensions produce a nil dimensions field")
  func allNilDimensions() throws {
    let row = Self.a320ACDRow(
      MTOW: 12_500,
      wingspan: nil,
      length: nil,
      tailHeight: nil
    )
    let APD = Self.minimalAPDRecord(ICAO: "A320")
    let result = Builder.build(ACDRows: [row], APDRecords: ["A320": APD])

    let profile = try #require(result["A320"])
    #expect(profile.dimensions == nil)
  }

  @Test("Performance phases prune themselves when no fields are populated")
  func performancePhasePruning() throws {
    let APD = Self.minimalAPDRecord(ICAO: "X999")
    let result = Builder.build(ACDRows: [], APDRecords: ["X999": APD])

    let profile = try #require(result["X999"])
    let performance = try #require(profile.performance)
    #expect(performance.takeoff != nil)
    #expect(performance.takeoff?.v2Kt == 145)
    #expect(performance.takeoff?.distanceFt == 6_900)
    #expect(performance.climb == nil)
    #expect(performance.cruise == nil)
    #expect(performance.descent == nil)
    #expect(performance.approach == nil)
    #expect(performance.landing == nil)
  }

  @Test("Empty inputs produce empty output")
  func emptyInputs() {
    let result = Builder.build(ACDRows: [], APDRecords: [:])
    #expect(result.isEmpty)
  }

  @Test("Disjoint sources produce one profile per ICAO with the correct source flag")
  func disjointSources() throws {
    let ACDOnly = Self.a320ACDRow(ICAO: "C172", model: "172R", MTOW: 2_550)
    let APDOnly = Self.a320APDRecord(ICAO: "B748")
    let result = Builder.build(
      ACDRows: [ACDOnly],
      APDRecords: ["B748": APDOnly]
    )

    let c172 = try #require(result["C172"])
    let b748 = try #require(result["B748"])
    #expect(c172.sources == .ACD)
    #expect(b748.sources == .APD)
    #expect(result.count == 2)
  }
}
