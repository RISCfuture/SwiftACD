import Foundation

struct ACDRow: Sendable, Hashable {
  // 1-based row number in the source spreadsheet, used in error messages.
  let rowNumber: Int

  let ICAOTypeDesignator: String
  let manufacturer: String?
  let model: String?

  let approachCategory: AircraftApproachCategory?
  let designGroup: AirplaneDesignGroup?
  let taxiwayDesignGroup: TaxiwayDesignGroup?

  let MTOWLb: Double?
  let mainGearWidthFt: Double?
  let cockpitToMainGearFt: Double?

  let wingspanFt: Double?
  let lengthFt: Double?
  let tailHeightFt: Double?

  let approachSpeedKt: Double?
}
