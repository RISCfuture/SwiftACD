import Foundation

/// Airport- and operations-design classifications attached to an aircraft type.
///
/// `AAC` and the design groups come from the FAA Aircraft Characteristics
/// Database. Wake-turbulence classifications come from the EUROCONTROL
/// Aircraft Performance Database.
public struct Categories: Sendable, Codable, Hashable {

  /// FAA Aircraft Approach Category (AAC). EUROCONTROL APC fills in when ACD
  /// has no value.
  public let approach: AircraftApproachCategory?

  /// FAA Airplane Design Group (ADG), I–VI.
  public let designGroup: AirplaneDesignGroup?

  /// FAA Taxiway Design Group (TDG), 1A–7.
  public let taxiwayDesignGroup: TaxiwayDesignGroup?

  /// ICAO Wake Turbulence Category (WTC) as published by EUROCONTROL.
  public let wakeTurbulence: WakeTurbulenceCategory?

  /// EUROCONTROL RECAT-EU classification.
  public let RECAT_EU: RECATEU?

  /// Memberwise initializer. All fields default to `nil`.
  public init(
    approach: AircraftApproachCategory? = nil,
    designGroup: AirplaneDesignGroup? = nil,
    taxiwayDesignGroup: TaxiwayDesignGroup? = nil,
    wakeTurbulence: WakeTurbulenceCategory? = nil,
    RECAT_EU: RECATEU? = nil
  ) {
    self.approach = approach
    self.designGroup = designGroup
    self.taxiwayDesignGroup = taxiwayDesignGroup
    self.wakeTurbulence = wakeTurbulence
    self.RECAT_EU = RECAT_EU
  }
}

/// FAA Aircraft Approach Category (also EUROCONTROL APC).
///
/// Defined by Vat (1.3 × Vso at maximum landing weight) per FAA AC 150/5300-13.
public enum AircraftApproachCategory: String, Sendable, Codable, Hashable, CaseIterable {
  /// Vat < 91 kt
  case a = "A"
  /// 91 kt ≤ Vat < 121 kt
  case b = "B"
  /// 121 kt ≤ Vat < 141 kt
  case c = "C"
  /// 141 kt ≤ Vat < 166 kt
  case d = "D"
  /// Vat ≥ 166 kt
  case e = "E"
}

/// FAA Airplane Design Group, derived from wingspan and tail height
/// (per FAA AC 150/5300-13). Higher groups admit larger aircraft.
public enum AirplaneDesignGroup: String, Sendable, Codable, Hashable, CaseIterable {
  /// Wingspan < 49 ft, tail height < 20 ft.
  case I = "I"
  /// 49 ft ≤ wingspan < 79 ft, 20 ft ≤ tail height < 30 ft.
  case II = "II"
  /// 79 ft ≤ wingspan < 118 ft, 30 ft ≤ tail height < 45 ft.
  case III = "III"
  /// 118 ft ≤ wingspan < 171 ft, 45 ft ≤ tail height < 60 ft.
  case IV = "IV"
  /// 171 ft ≤ wingspan < 214 ft, 60 ft ≤ tail height < 66 ft.
  case V = "V"
  /// 214 ft ≤ wingspan < 262 ft, 66 ft ≤ tail height < 80 ft.
  case VI = "VI"
}

/// FAA Taxiway Design Group, derived from main gear width (MGW) and the
/// distance between the cockpit and the main gear (CMG). Per FAA AC
/// 150/5300-13.
public enum TaxiwayDesignGroup: String, Sendable, Codable, Hashable, CaseIterable {
  /// MGW < 15 ft, CMG < 18 ft.
  case group1A = "1A"
  /// MGW < 15 ft, 18 ft ≤ CMG < 60 ft.
  case group1B = "1B"
  /// 15 ft ≤ MGW < 26 ft, CMG < 18 ft.
  case group2A = "2A"
  /// 15 ft ≤ MGW < 26 ft, 18 ft ≤ CMG < 60 ft.
  case group2B = "2B"
  /// MGW < 15 ft, CMG ≥ 60 ft.
  case group3 = "3"
  /// 15 ft ≤ MGW < 26 ft, CMG ≥ 60 ft.
  case group4 = "4"
  /// 26 ft ≤ MGW < 30 ft.
  case group5 = "5"
  /// 30 ft ≤ MGW < 40 ft.
  case group6 = "6"
  /// MGW ≥ 40 ft.
  case group7 = "7"
}

/// ICAO Wake Turbulence Category as published by EUROCONTROL.
public enum WakeTurbulenceCategory: String, Sendable, Codable, Hashable, CaseIterable {
  /// MTOW ≤ 7,000 kg
  case light = "L"
  /// 7,000 kg < MTOW < 136,000 kg
  case medium = "M"
  /// MTOW ≥ 136,000 kg
  case heavy = "H"
  /// A380 / AN-225 class
  case `super` = "J"
}

/// EUROCONTROL RECAT-EU separation category.
///
/// Raw values match the human-readable strings the APD page emits (e.g.
/// `"Upper Heavy"`); use ``code`` for the formal `CAT-X` identifier.
public enum RECATEU: String, Sendable, Codable, Hashable, CaseIterable {
  /// `CAT-A`. Super-heavy class (A380, AN-225).
  case superHeavy = "Super Heavy"
  /// `CAT-B`. MTOW > 100 t with MTOW > 198 t threshold.
  case upperHeavy = "Upper Heavy"
  /// `CAT-C`. Heavy class with MTOW between 100 t and 198 t.
  case lowerHeavy = "Lower Heavy"
  /// `CAT-D`. Upper medium class (≈ 15 t < MTOW ≤ 100 t with high wingspan).
  case upperMedium = "Upper Medium"
  /// `CAT-E`. Lower medium class.
  case lowerMedium = "Lower Medium"
  /// `CAT-F`. Light class (MTOW ≤ 15 t).
  case light = "Light"

  /// Formal RECAT-EU code (e.g. `CAT-A`).
  public var code: String {
    switch self {
      case .superHeavy: return "CAT-A"
      case .upperHeavy: return "CAT-B"
      case .lowerHeavy: return "CAT-C"
      case .upperMedium: return "CAT-D"
      case .lowerMedium: return "CAT-E"
      case .light: return "CAT-F"
    }
  }
}
