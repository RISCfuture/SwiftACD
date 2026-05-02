import Foundation

struct APDRecord: Sendable, Hashable {
  let ICAOTypeDesignator: String
  let identity: Identity
  let categories: Categories
  let recognition: Recognition
  let dimensions: Dimensions
  let weights: Weights
  let performance: Performance
}

extension APDRecord {

  struct Identity: Sendable, Hashable {
    let manufacturer: String?
    let model: String?
    let IATACodes: [String]
    let alternativeNames: [String]
    let aircraftClass: AircraftClass?
    let engineCount: EngineCount?
    let engineType: EngineType?
  }

  struct Categories: Sendable, Hashable {
    let approachCategory: AircraftApproachCategory?
    let wakeTurbulence: WakeTurbulenceCategory?
    let RECAT_EU: RECATEU?
  }

  struct Recognition: Sendable, Hashable {
    let wing: String?
    let engine: String?
    let tail: String?
    let landingGear: String?
  }

  // Stored in feet (converted from meters at parse time).
  struct Dimensions: Sendable, Hashable {
    let wingspanFt: Double?
    let lengthFt: Double?
    let heightFt: Double?
  }

  struct Weights: Sendable, Hashable {
    let MTOWLb: Double?
  }

  struct Performance: Sendable, Hashable {
    let takeoff: Takeoff
    let climb: Climb
    let cruise: Cruise
    let descent: Descent
    let approach: Approach
    let landing: Landing

    struct Takeoff: Sendable, Hashable {
      let v2Kt: Double?
      let distanceFt: Double?
    }

    struct Climb: Sendable, Hashable {
      let initialIASKt: Double?
      let initialRateOfClimbFPM: Double?
      let to150IASKt: Double?
      let to150RateOfClimbFPM: Double?
      let to240IASKt: Double?
      let to240RateOfClimbFPM: Double?
      let machClimbMach: Double?
    }

    struct Cruise: Sendable, Hashable {
      let TASKt: Double?
      let mach: Double?
      let ceilingFL: Int?
      let rangeNmi: Double?
    }

    struct Descent: Sendable, Hashable {
      let initialIASKt: Double?
      let initialRateOfDescentFPM: Double?
      let descentIASKt: Double?
      let descentRateOfDescentFPM: Double?
    }

    struct Approach: Sendable, Hashable {
      let IASKt: Double?
      let minimumCleanSpeedKt: Double?
      let rateOfDescentFPM: Double?
    }

    struct Landing: Sendable, Hashable {
      let vatKt: Double?
      let distanceFt: Double?
    }
  }
}
