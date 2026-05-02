import Foundation
import SwiftSoup

struct APDParser {

  // Directory containing `<ICAO>.html` files emitted by `APDDownloader`.
  let directory: URL

  static func parseFile(at url: URL, ICAO: String) throws -> APDRecord {
    let html: String
    do {
      html = try String(contentsOf: url, encoding: .utf8)
    } catch {
      throw SwiftACDError.malformedAPDPage(
        ICAO: ICAO,
        reason: .fileReadFailed(underlying: error.localizedDescription)
      )
    }
    let document: Document
    do {
      document = try SwiftSoup.parse(html)
    } catch {
      throw SwiftACDError.malformedAPDPage(
        ICAO: ICAO,
        reason: .htmlParseFailed(underlying: error.localizedDescription)
      )
    }
    return try parseDocument(document, ICAO: ICAO)
  }

  // `ICAO` is drawn from the filename and trusted as the record's primary key
  // even on the empty fallback page (whose `MainContent_wsICAOLabel` is the
  // literal string `"No"`).
  static func parseDocument(_ document: Document, ICAO: String) throws -> APDRecord {
    // Top-level identity / dimensions / recognition.
    let manufacturer = APDExtractors.meaningfulText(
      document,
      id: "MainContent_wsManufacturerLabel"
    )
    let model = APDExtractors.meaningfulText(document, id: "MainContent_wsAcftNameLabel")

    // Type code: e.g. "L2J" → AircraftClass.landplane / EngineCount.number(2)
    // / EngineType.jet. Empty or "No" → all three nil.
    let typeCode = APDExtractors.meaningfulText(document, id: "MainContent_wsTypeLabel")
    let aircraftClass: AircraftClass?
    let engineCount: EngineCount?
    let engineType: EngineType?
    if let typeCode, typeCode.count == 3 {
      let chars = Array(typeCode)
      aircraftClass = AircraftClass(rawValue: String(chars[0]))
      engineCount = EngineCount(ICAOCode: chars[1])
      engineType = EngineType(rawValue: String(chars[2]))
    } else {
      aircraftClass = nil
      engineCount = nil
      engineType = nil
    }

    // Categories.
    let approachCategory = parseEnum(
      AircraftApproachCategory.self,
      raw: APDExtractors.meaningfulText(document, id: "MainContent_wsAPCLabel")
    )
    let wakeTurbulence = parseEnum(
      WakeTurbulenceCategory.self,
      raw: APDExtractors.meaningfulText(document, id: "MainContent_wsWTCLabel")
    )
    let RECAT_EU = parseEnum(
      RECATEU.self,
      raw: APDExtractors.meaningfulText(document, id: "MainContent_wsRecatEULabel")
    )

    // Recognition.
    let wing = APDExtractors.meaningfulText(document, id: "MainContent_wsLabelWingPosition")
    let engine = APDExtractors.meaningfulText(document, id: "MainContent_wsLabelEngineData")
    let tail = APDExtractors.meaningfulText(document, id: "MainContent_wsLabelTailPosition")
    let landingGear = APDExtractors.meaningfulText(
      document,
      id: "MainContent_wsLabelLandingGear"
    )

    // Dimensions — APD publishes meters, we store feet.
    let wingspanFt = APDExtractors.meaningfulText(document, id: "MainContent_wsLabelWingSpan")
      .flatMap(APDExtractors.parseDouble)
      .map(metersToFeet)
    let lengthFt = APDExtractors.meaningfulText(document, id: "MainContent_wsLabelLength")
      .flatMap(APDExtractors.parseDouble)
      .map(metersToFeet)
    let heightFt = APDExtractors.meaningfulText(document, id: "MainContent_wsLabelHeight")
      .flatMap(APDExtractors.parseDouble)
      .map(metersToFeet)

    // IATA + alternative names.
    let IATACodes = APDExtractors.splitSlashSeparated(document, id: "MainContent_wsIATACode")
    let alternativeNames = APDExtractors.alternativeNames(document)

    // Performance.
    let MTOWLb = APDExtractors.perfDouble(document, datagraph: "takeOffMTOW")
      .map { Measurement(value: $0, unit: UnitMass.kilograms).converted(to: .pounds).value }

    let takeoffDistanceFt = APDExtractors.perfDouble(document, datagraph: "takeOffDistance")
      .map(metersToFeet)

    let landingDistanceFt = APDExtractors.perfDouble(document, datagraph: "landingDistance")
      .map(metersToFeet)

    // Cruise ceiling: APD always writes flight levels (the cell is preceded
    // by an `FL` unit span). Stored as an integer FL — pressure altitudes
    // aren't directly convertible to feet.
    let cruiseCeilingFL = parseCeiling(document)

    return APDRecord(
      ICAOTypeDesignator: ICAO,
      identity: APDRecord.Identity(
        manufacturer: manufacturer,
        model: model,
        IATACodes: IATACodes,
        alternativeNames: alternativeNames,
        aircraftClass: aircraftClass,
        engineCount: engineCount,
        engineType: engineType
      ),
      categories: APDRecord.Categories(
        approachCategory: approachCategory,
        wakeTurbulence: wakeTurbulence,
        RECAT_EU: RECAT_EU
      ),
      recognition: APDRecord.Recognition(
        wing: wing,
        engine: engine,
        tail: tail,
        landingGear: landingGear
      ),
      dimensions: APDRecord.Dimensions(
        wingspanFt: wingspanFt,
        lengthFt: lengthFt,
        heightFt: heightFt
      ),
      weights: APDRecord.Weights(MTOWLb: MTOWLb),
      performance: APDRecord.Performance(
        takeoff: APDRecord.Performance.Takeoff(
          v2Kt: APDExtractors.perfDouble(document, datagraph: "takeOffV2"),
          distanceFt: takeoffDistanceFt
        ),
        climb: APDRecord.Performance.Climb(
          initialIASKt: APDExtractors.perfDouble(document, datagraph: "initialClimbIAS"),
          initialRateOfClimbFPM: APDExtractors.perfDouble(document, datagraph: "initialClimbROC"),
          to150IASKt: APDExtractors.perfDouble(document, datagraph: "climb150IAS"),
          to150RateOfClimbFPM: APDExtractors.perfDouble(document, datagraph: "climb150ROC"),
          to240IASKt: APDExtractors.perfDouble(document, datagraph: "climb240IAS"),
          to240RateOfClimbFPM: APDExtractors.perfDouble(document, datagraph: "climb240ROC"),
          machClimbMach: APDExtractors.perfDouble(document, datagraph: "machClimbMACH")
        ),
        cruise: APDRecord.Performance.Cruise(
          TASKt: APDExtractors.perfDouble(document, datagraph: "cruiseTAS"),
          mach: APDExtractors.perfDouble(document, datagraph: "cruiseMACH"),
          ceilingFL: cruiseCeilingFL,
          rangeNmi: APDExtractors.perfDouble(document, datagraph: "cruiseRange")
        ),
        descent: APDRecord.Performance.Descent(
          // The `initialDescentMACH` datagraph is always a Mach number
          // (label `MACH`, value ≤ 1.00 across every observed APD page);
          // it is never IAS, so this slot stays empty.
          initialIASKt: nil,
          initialRateOfDescentFPM: APDExtractors.perfDouble(
            document,
            datagraph: "initialDescentROD"
          ),
          descentIASKt: APDExtractors.perfDouble(document, datagraph: "descentIAS"),
          descentRateOfDescentFPM: APDExtractors.perfDouble(document, datagraph: "descentROD")
        ),
        approach: APDRecord.Performance.Approach(
          IASKt: APDExtractors.perfDouble(document, datagraph: "approachIAS"),
          minimumCleanSpeedKt: APDExtractors.perfDouble(document, datagraph: "approachMCS"),
          rateOfDescentFPM: APDExtractors.perfDouble(document, datagraph: "approachROD")
        ),
        landing: APDRecord.Performance.Landing(
          vatKt: APDExtractors.perfDouble(document, datagraph: "landingVat"),
          distanceFt: landingDistanceFt
        )
      )
    )
  }

  // MARK: - Field helpers

  // Unknown raw values yield `nil` rather than throwing — EUROCONTROL
  // occasionally emits literal placeholder text (e.g. `"APC"` on the
  // schema-only fallback page) and we'd rather skip the field than abort.
  private static func parseEnum<E: RawRepresentable>(
    _: E.Type,
    raw: String?
  ) -> E? where E.RawValue == String {
    guard let raw else { return nil }
    if APDExtractors.isPlaceholder(raw) { return nil }
    return E(rawValue: raw)
  }

  // EUROCONTROL publishes flight levels here (raw value is the level number,
  // e.g. `"410"` for FL 410). Stored as an integer FL because pressure
  // altitudes can't be converted to feet without a local altimeter setting.
  private static func parseCeiling(_ document: Document) -> Int? {
    APDExtractors.perfDouble(document, datagraph: "cruiseCeiling").map { Int($0) }
  }

  func parse(
    errorCallback: @escaping @Sendable (Error) -> Void
  ) async throws -> [String: APDRecord] {
    let fileManager = FileManager.default
    let contents = try fileManager.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    let htmlFiles = contents.filter { $0.pathExtension.lowercased() == "html" }

    return try await withThrowingTaskGroup(of: (String, APDRecord)?.self) { group in
      for url in htmlFiles {
        let ICAO = url.deletingPathExtension().lastPathComponent
        group.addTask {
          do {
            let record = try Self.parseFile(at: url, ICAO: ICAO)
            return (ICAO, record)
          } catch {
            errorCallback(error)
            return nil
          }
        }
      }

      var records: [String: APDRecord] = [:]
      records.reserveCapacity(htmlFiles.count)
      for try await result in group {
        if let (ICAO, record) = result {
          records[ICAO] = record
        }
      }
      return records
    }
  }
}

// EUROCONTROL publishes dimensions in meters; SwiftACD stores them in feet.
// Routing through Foundation's exact 0.3048 conversion avoids drift from a
// hand-rolled multiplier.
private func metersToFeet(_ meters: Double) -> Double {
  Measurement(value: meters, unit: UnitLength.meters).converted(to: .feet).value
}
