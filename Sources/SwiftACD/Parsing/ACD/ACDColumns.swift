import Foundation

// Column order has shifted between FAA workbook revisions, so we match on
// header text (case- and punctuation-insensitive) rather than by index.
struct ACDColumns: Sendable {
  let ICAO: Int
  let manufacturer: Int?
  let model: Int?
  let approachCategory: Int?
  let designGroup: Int?
  let taxiwayDesignGroup: Int?
  let MTOW: Int?
  let mainGearWidth: Int?
  let cockpitToMainGear: Int?
  let wingspan: Int?
  let length: Int?
  let tailHeight: Int?
  let approachSpeed: Int?

  // ICAO is the only required column; throws if it cannot be located.
  static func resolve(headerRow: [String]) throws -> Self {
    let normalized = headerRow.map(Self.normalize)

    func find(_ candidates: [String]) -> Int? {
      let needles = candidates.map(Self.normalize)
      return normalized.firstIndex { cell in
        needles.contains { cell.contains($0) }
      }
    }

    guard let ICAO = find(["icao", "designator", "type designator"]) else {
      throw SwiftACDError.missingACDColumn(field: "ICAO Type Designator")
    }

    return Self(
      ICAO: ICAO,
      manufacturer: find(["manufacturer", "make"]),
      model: find(["model", "aircraft model", "variant"]),
      approachCategory: find(["aac", "approach category"]),
      designGroup: find(["adg", "design group", "airplane design group"]),
      taxiwayDesignGroup: find(["tdg", "taxiway"]),
      MTOW: find(["mtow", "max takeoff", "maximum takeoff", "mgw lbs", "max takeoff weight"]),
      mainGearWidth: find(["mgw", "main gear width", "main landing gear width"]),
      cockpitToMainGear: find(["cmg", "cockpit to main", "cockpit to main gear"]),
      wingspan: find(["wingspan", "wing span"]),
      length: find(["length", "fuselage length", "overall length"]),
      tailHeight: find(["tail height", "height", "vertical tail"]),
      approachSpeed: find(["approach speed", "vref", "vat"])
    )
  }

  // Lowercase, strip punctuation, and collapse whitespace so header variations
  // like `"MTOW (lbs)"` and `"MTOW lbs."` collide.
  private static func normalize(_ string: String) -> String {
    let lowered = string.lowercased()
    let scalars = lowered.unicodeScalars.map { scalar -> String in
      if CharacterSet.alphanumerics.contains(scalar) { return String(scalar) }
      return " "
    }
    return scalars.joined().split(separator: " ").joined(separator: " ")
  }
}
