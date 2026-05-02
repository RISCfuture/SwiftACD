import Foundation

/// Identity fields for an aircraft type. The ICAO type designator is the
/// primary key; everything else is descriptive.
public struct Identity: Sendable, Codable, Hashable {

  /// ICAO aircraft type designator (e.g. `B738`, `A320`, `C172`).
  public let ICAOTypeDesignator: String

  /// IATA aircraft type code(s), when EUROCONTROL publishes them. Multiple
  /// codes (separated by `/` in the source) are split into individual entries.
  public let IATACodes: [String]

  /// Manufacturer name (e.g. `Boeing`, `Airbus`, `Cessna`).
  public let manufacturer: String?

  /// Model / common name.
  public let model: String?

  /// Free-text alternative names recorded by EUROCONTROL (variant nicknames,
  /// military designations, etc.). Empty when none are known.
  public let alternativeNames: [String]

  /// Aircraft class — landplane, seaplane, helicopter, etc.
  public let aircraftClass: AircraftClass?

  /// Number of engines.
  public let engineCount: EngineCount?

  /// Engine type (turbofan, turboprop, piston, …).
  public let engineType: EngineType?

  /// Memberwise initializer. Only ``ICAOTypeDesignator`` is required; all
  /// other fields default to absent.
  public init(
    ICAOTypeDesignator: String,
    IATACodes: [String] = [],
    manufacturer: String? = nil,
    model: String? = nil,
    alternativeNames: [String] = [],
    aircraftClass: AircraftClass? = nil,
    engineCount: EngineCount? = nil,
    engineType: EngineType? = nil
  ) {
    self.ICAOTypeDesignator = ICAOTypeDesignator
    self.IATACodes = IATACodes
    self.manufacturer = manufacturer
    self.model = model
    self.alternativeNames = alternativeNames
    self.aircraftClass = aircraftClass
    self.engineCount = engineCount
    self.engineType = engineType
  }
}

/// Top-level aircraft class as encoded in the first character of the ICAO
/// Doc 8643 description code (e.g. `L` in `L2J`).
public enum AircraftClass: String, Sendable, Codable, Hashable, CaseIterable {
  /// Landplane.
  case landplane = "L"
  /// Seaplane.
  case seaplane = "S"
  /// Amphibian.
  case amphibian = "A"
  /// Helicopter.
  case helicopter = "H"
  /// Gyrocopter / autogyro.
  case gyrocopter = "G"
  /// Tilt-rotor.
  case tiltrotor = "T"
  /// Balloon (free balloon, including airships in some sources).
  case balloon = "B"
}

/// Powerplant type, encoded in the third character of the ICAO Doc 8643
/// description code (e.g. `J` in `L2J`).
public enum EngineType: String, Sendable, Codable, Hashable, CaseIterable {
  /// Reciprocating piston engine.
  case piston = "P"
  /// Turboprop / turboshaft.
  case turboprop = "T"
  /// Turbojet / turbofan.
  case jet = "J"
  /// Rocket motor.
  case rocket = "R"
  /// Electric motor.
  case electric = "E"
}

/// Engine count encoded in the second character of the ICAO Doc 8643
/// description code (e.g. `2` in `L2J`). The ICAO `C` value (engines
/// mechanically coupled, no fixed count) is represented by ``coupled``.
public enum EngineCount: Sendable, Hashable {
  /// A specific number of engines (e.g. `.number(2)` for a typical airliner).
  case number(Int)
  /// Engines are mechanically coupled — no fixed count is reported.
  case coupled

  /// The ICAO Doc 8643 single-character code corresponding to this value
  /// (`"1"`–`"9"` for a specific number, `"C"` for ``coupled``).
  public var ICAOCode: String {
    switch self {
      case let .number(n): return String(n)
      case .coupled: return "C"
    }
  }

  /// Decode the single ICAO code character (`'1'`–`'9'` or `'C'`).
  ///
  /// Returns `nil` for any other character (including `'0'` and digits
  /// outside the published range).
  init?(ICAOCode: Character) {
    if ICAOCode == "C" || ICAOCode == "c" {
      self = .coupled
      return
    }
    guard let digit = ICAOCode.wholeNumberValue, digit > 0 else { return nil }
    self = .number(digit)
  }
}

extension EngineCount: Codable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)
    guard let first = raw.first, let value = EngineCount(ICAOCode: first) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unknown ICAO engine-count code \(raw)"
      )
    }
    self = value
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(ICAOCode)
  }
}
