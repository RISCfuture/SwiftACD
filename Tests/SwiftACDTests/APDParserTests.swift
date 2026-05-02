import Foundation
import Testing

@testable import SwiftACD

@Suite("APD parser")
struct APDParserTests {

  // MARK: - Fixture helpers

  static func resources() throws -> URL {
    try #require(Bundle.module.resourceURL).appendingPathComponent("TestResources")
  }

  static func fixture(_ name: String) throws -> URL {
    try resources().appendingPathComponent(name)
  }

  /// Parse a single fixture by name and return the resulting record.
  static func parse(_ filename: String, ICAO: String) throws -> APDRecord {
    let url = try fixture(filename)
    return try APDParser.parseFile(at: url, ICAO: ICAO)
  }

  // MARK: - Tolerance for converted Doubles

  static func approxEqual(
    _ a: Double?,
    _ b: Double,
    tolerance: Double = 0.5
  ) -> Bool {
    guard let a else { return false }
    return abs(a - b) <= tolerance
  }

  // MARK: - Source-unit conversion helpers

  /// APD publishes lengths in meters; the parser stores feet. Mirror that
  /// conversion through `Measurement` so test expectations don't bake in a
  /// hand-rolled coefficient.
  static func metersToFeet(_ meters: Double) -> Double {
    Measurement(value: meters, unit: UnitLength.meters).converted(to: .feet).value
  }

  /// APD publishes mass in kilograms; the parser stores pounds. Conversion
  /// goes through `Measurement` for the same reason as ``metersToFeet(_:)``.
  static func kilogramsToPounds(_ kilograms: Double) -> Double {
    Measurement(value: kilograms, unit: UnitMass.kilograms).converted(to: .pounds).value
  }

  // MARK: - Per-aircraft assertions

  @Test("A320 — narrowbody jet identity, dimensions, performance")
  func parseA320() throws {
    let r = try Self.parse("apd_A320.html", ICAO: "A320")

    #expect(r.ICAOTypeDesignator == "A320")
    #expect(r.identity.manufacturer == "AIRBUS")
    #expect(r.identity.model?.contains("A320") == true)

    #expect(r.identity.aircraftClass == .landplane)
    #expect(r.identity.engineCount == .number(2))
    #expect(r.identity.engineType == .jet)

    #expect(r.categories.approachCategory == .c)
    #expect(r.categories.wakeTurbulence == .medium)
    #expect(r.categories.RECAT_EU == .upperMedium)

    #expect(r.recognition.wing == "Low wing")
    #expect(r.recognition.engine == "Underwing mounted")
    #expect(r.recognition.tail == "Regular tail, mid set")
    #expect(r.recognition.landingGear == "Tricycle retractable")

    #expect(r.identity.IATACodes.contains("320"))
    #expect(r.identity.IATACodes.contains("32S"))

    // APD publishes wingspan/length/height in meters; we expect ft.
    #expect(Self.approxEqual(r.dimensions.wingspanFt, Self.metersToFeet(34.1)))
    #expect(Self.approxEqual(r.dimensions.lengthFt, Self.metersToFeet(37.57)))
    #expect(Self.approxEqual(r.dimensions.heightFt, Self.metersToFeet(11.76)))

    #expect(r.performance.takeoff.v2Kt == 145)
    // APD publishes MTOW in kg; we expect lb.
    #expect(Self.approxEqual(r.weights.MTOWLb, Self.kilogramsToPounds(73_900), tolerance: 1.0))

    #expect(r.performance.cruise.mach == 0.79)
    // APD publishes the cruise ceiling as a flight level; stored verbatim.
    #expect(r.performance.cruise.ceilingFL == 390)
    #expect(r.performance.cruise.rangeNmi == 2700)
    #expect(r.performance.cruise.TASKt == 450)

    #expect(r.performance.landing.vatKt == 137)
    // APD publishes landing distance in meters; we expect ft.
    #expect(
      Self.approxEqual(r.performance.landing.distanceFt, Self.metersToFeet(1_440), tolerance: 1.0)
    )

    // initialDescentMACH on the A320 is "0.78" with no kt unit → not stored as IAS.
    #expect(r.performance.descent.initialIASKt == nil)

    #expect(r.identity.alternativeNames.contains(where: { $0.contains("A-320") }))
  }

  @Test("B738 — narrowbody jet")
  func parseB738() throws {
    let r = try Self.parse("apd_B738.html", ICAO: "B738")

    #expect(r.ICAOTypeDesignator == "B738")
    #expect(r.identity.manufacturer == "BOEING")
    #expect(r.identity.aircraftClass == .landplane)
    #expect(r.identity.engineCount == .number(2))
    #expect(r.identity.engineType == .jet)
    #expect(r.performance.takeoff.v2Kt == 145)
    #expect(r.performance.cruise.mach == 0.79)
    #expect(r.identity.IATACodes.contains("738"))
  }

  @Test("C172 — single-engine piston")
  func parseC172() throws {
    let r = try Self.parse("apd_C172.html", ICAO: "C172")

    #expect(r.identity.aircraftClass == .landplane)
    #expect(r.identity.engineCount == .number(1))
    #expect(r.identity.engineType == .piston)

    #expect(r.categories.wakeTurbulence == .light)
    #expect(r.categories.RECAT_EU == .light)

    #expect(r.recognition.wing == "High wing (wing struts)")
    #expect(r.recognition.engine == "Nose mounted")
    #expect(r.recognition.landingGear == "Tricycle fixed")

    #expect(r.performance.cruise.mach == nil)
    #expect(r.identity.IATACodes.isEmpty)

    #expect(r.performance.takeoff.v2Kt == 60)
    #expect(r.performance.landing.vatKt == 65)
  }

  @Test("B748 — heavy jet")
  func parseB748() throws {
    let r = try Self.parse("apd_B748.html", ICAO: "B748")

    #expect(r.identity.aircraftClass == .landplane)
    #expect(r.identity.engineCount == .number(4))
    #expect(r.identity.engineType == .jet)

    #expect(r.categories.wakeTurbulence == .heavy)
    #expect(r.categories.RECAT_EU == .upperHeavy)

    #expect(r.recognition.wing == "Low swept wing (Raked wings)")
    #expect(r.recognition.tail == "Regular tail, low set")

    #expect(r.performance.takeoff.v2Kt == 175)
    #expect(r.performance.cruise.mach == 0.86)
  }

  @Test("EC25 — empty/sparse fallback page parses without throwing")
  func parseEC25() throws {
    let r = try Self.parse("apd_EC25.html", ICAO: "EC25")

    #expect(r.ICAOTypeDesignator == "EC25")
    #expect(r.identity.manufacturer == nil)
    #expect(r.identity.model == nil)
    #expect(r.identity.aircraftClass == nil)
    #expect(r.identity.engineCount == nil)
    #expect(r.identity.engineType == nil)
    #expect(r.categories.approachCategory == nil)
    #expect(r.categories.wakeTurbulence == nil)
    #expect(r.categories.RECAT_EU == nil)
    #expect(r.recognition.wing == nil)
    #expect(r.recognition.engine == nil)
    #expect(r.recognition.tail == nil)
    #expect(r.recognition.landingGear == nil)
    #expect(r.dimensions.wingspanFt == nil)
    #expect(r.dimensions.lengthFt == nil)
    #expect(r.dimensions.heightFt == nil)
    #expect(r.weights.MTOWLb == nil)
    #expect(r.performance.takeoff.v2Kt == nil)
    #expect(r.performance.cruise.mach == nil)
    #expect(r.identity.IATACodes.isEmpty)
    #expect(r.identity.alternativeNames.isEmpty)
  }

  // MARK: - Directory walk

  @Test("Directory parse picks up every fixture HTML keyed by ICAO")
  func parseDirectory() async throws {
    let tmp = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: tmp) }

    let ICAOs = ["A320", "B738", "C172", "B748", "EC25"]
    for ICAO in ICAOs {
      let source = try Self.fixture("apd_\(ICAO).html")
      let dest = tmp.appendingPathComponent("\(ICAO).html")
      try FileManager.default.copyItem(at: source, to: dest)
    }

    let errors = ErrorBox()
    let parser = APDParser(directory: tmp)
    let records = try await parser.parse(errorCallback: { errors.append($0) })

    #expect(errors.all.isEmpty)
    #expect(records.count == ICAOs.count)
    for ICAO in ICAOs {
      #expect(records[ICAO] != nil, "missing record for \(ICAO)")
      #expect(records[ICAO]?.ICAOTypeDesignator == ICAO)
    }
  }

  @Test("Unreadable file surfaces malformedAPDPage and the parse continues")
  func malformedFileSurfacesError() async throws {
    let tmp = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: tmp) }

    let valid = try Self.fixture("apd_A320.html")
    try FileManager.default.copyItem(at: valid, to: tmp.appendingPathComponent("A320.html"))

    let bogus = tmp.appendingPathComponent("XXXX.html")
    try Data([0xff, 0xfe, 0xfd]).write(to: bogus)

    let errors = ErrorBox()
    let parser = APDParser(directory: tmp)
    let records = try await parser.parse(errorCallback: { errors.append($0) })

    #expect(records["A320"] != nil)
    #expect(records["XXXX"] == nil)
    #expect(
      errors.all.contains { error in
        guard case let SwiftACDError.malformedAPDPage(ICAO, _) = error else { return false }
        return ICAO == "XXXX"
      }
    )
  }

  // MARK: - Utilities

  private func makeTempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftACDTests-APD-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
}

/// Lock-guarded error accumulator usable from a `@Sendable` callback.
private final class ErrorBox: @unchecked Sendable {
  private let lock = NSLock()
  private var errors: [Error] = []

  var all: [Error] {
    lock.lock()
    defer { lock.unlock() }
    return errors
  }

  func append(_ error: Error) {
    lock.lock()
    errors.append(error)
    lock.unlock()
  }
}
