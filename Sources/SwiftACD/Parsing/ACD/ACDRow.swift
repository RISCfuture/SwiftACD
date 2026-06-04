import Foundation

struct ACDRow: Sendable, Hashable {
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
