import Foundation

// Merge rule: prefer FAA, fall back to APD for any field published by both
// sources. FAA-only fields (ADG, TDG, MGW, CMG) come from the first ACD row;
// APD-only fields (IATA codes, RECAT-EU, recognition, performance envelope)
// come straight from the APD record.
struct Builder: Sendable {

  static func build(
    ACDRows: [ACDRow],
    APDRecords: [String: APDRecord]
  ) -> [String: AircraftProfile] {
    let groupedACD = Dictionary(grouping: ACDRows, by: \.ICAOTypeDesignator)
    let ICAOs = Set(groupedACD.keys).union(APDRecords.keys)

    var output: [String: AircraftProfile] = [:]
    output.reserveCapacity(ICAOs.count)

    for ICAO in ICAOs {
      let rows = groupedACD[ICAO] ?? []
      let APD = APDRecords[ICAO]
      output[ICAO] = makeProfile(ICAO: ICAO, ACDRows: rows, APD: APD)
    }
    return output
  }

  // MARK: - Profile assembly

  private static func makeProfile(
    ICAO: String,
    ACDRows: [ACDRow],
    APD: APDRecord?
  ) -> AircraftProfile {
    let primary = ACDRows.first

    let identity = Identity(
      ICAOTypeDesignator: ICAO,
      IATACodes: APD?.identity.IATACodes ?? [],
      manufacturer: primary?.manufacturer ?? APD?.identity.manufacturer,
      model: primary?.model ?? APD?.identity.model,
      alternativeNames: APD?.identity.alternativeNames ?? [],
      aircraftClass: APD?.identity.aircraftClass,
      engineCount: APD?.identity.engineCount,
      engineType: APD?.identity.engineType
    )

    let categories = Categories(
      approach: primary?.approachCategory ?? APD?.categories.approachCategory,
      designGroup: primary?.designGroup,
      taxiwayDesignGroup: primary?.taxiwayDesignGroup,
      wakeTurbulence: APD?.categories.wakeTurbulence,
      RECAT_EU: APD?.categories.RECAT_EU
    )

    let dimensions = mergedDimensions(primary: primary, APD: APD)
    let weights = mergedWeights(primary: primary, APD: APD)
    let recognition = recognition(from: APD?.recognition)
    let performance = performance(from: APD?.performance)

    let variants = ACDRows.enumerated().map { index, row in
      makeVariant(ICAO: ICAO, index: index, row: row)
    }

    var sources: Source = []
    if !ACDRows.isEmpty { sources.insert(.ACD) }
    if APD != nil { sources.insert(.APD) }

    return AircraftProfile(
      identity: identity,
      categories: categories,
      dimensions: dimensions,
      weights: weights,
      recognition: recognition,
      performance: performance,
      variants: variants,
      sources: sources
    )
  }

  // MARK: - Variant

  private static func makeVariant(ICAO: String, index: Int, row: ACDRow) -> Variant {
    let dims = dimensions(
      wingspan: row.wingspanFt,
      length: row.lengthFt,
      tailHeight: row.tailHeightFt
    )
    let wts = weights(
      MTOW: row.MTOWLb,
      mainGearWidth: row.mainGearWidthFt,
      cockpitToMainGear: row.cockpitToMainGearFt
    )
    let cats = Categories(
      approach: row.approachCategory,
      designGroup: row.designGroup,
      taxiwayDesignGroup: row.taxiwayDesignGroup,
      wakeTurbulence: nil,
      RECAT_EU: nil
    )
    return Variant(
      id: "\(ICAO)#\(index)",
      manufacturer: row.manufacturer,
      model: row.model,
      approachSpeedKt: row.approachSpeedKt,
      dimensions: dims,
      weights: wts,
      categories: cats
    )
  }

  // MARK: - Dimensions

  private static func mergedDimensions(primary: ACDRow?, APD: APDRecord?) -> Dimensions? {
    let wingspan = primary?.wingspanFt ?? APD?.dimensions.wingspanFt
    let length = primary?.lengthFt ?? APD?.dimensions.lengthFt
    let tailHeight = primary?.tailHeightFt ?? APD?.dimensions.heightFt
    return dimensions(wingspan: wingspan, length: length, tailHeight: tailHeight)
  }

  // Returns `nil` only when every component is `nil`; otherwise missing
  // components default to `0` so partial geometry still emits.
  private static func dimensions(
    wingspan: Double?,
    length: Double?,
    tailHeight: Double?
  ) -> Dimensions? {
    if wingspan == nil && length == nil && tailHeight == nil { return nil }
    return Dimensions(
      wingspanFt: wingspan ?? 0,
      lengthFt: length ?? 0,
      tailHeightFt: tailHeight ?? 0
    )
  }

  // MARK: - Weights

  private static func mergedWeights(primary: ACDRow?, APD: APDRecord?) -> Weights? {
    weights(
      MTOW: primary?.MTOWLb ?? APD?.weights.MTOWLb,
      mainGearWidth: primary?.mainGearWidthFt,
      cockpitToMainGear: primary?.cockpitToMainGearFt
    )
  }

  private static func weights(
    MTOW: Double?,
    mainGearWidth: Double?,
    cockpitToMainGear: Double?
  ) -> Weights? {
    guard let MTOW else { return nil }
    return Weights(
      MTOWLb: MTOW,
      mainGearWidthFt: mainGearWidth,
      cockpitToMainGearFt: cockpitToMainGear
    )
  }

  // MARK: - Recognition

  private static func recognition(from APD: APDRecord.Recognition?) -> Recognition? {
    guard let APD else { return nil }
    if APD.wing == nil && APD.engine == nil && APD.tail == nil && APD.landingGear == nil {
      return nil
    }
    return Recognition(
      wing: APD.wing,
      engine: APD.engine,
      tail: APD.tail,
      landingGear: APD.landingGear
    )
  }

  // MARK: - Performance

  private static func performance(from APD: APDRecord.Performance?) -> Performance? {
    guard let APD else { return nil }
    let takeoff = takeoff(from: APD.takeoff)
    let climb = climb(from: APD.climb)
    let cruise = cruise(from: APD.cruise)
    let descent = descent(from: APD.descent)
    let approach = approach(from: APD.approach)
    let landing = landing(from: APD.landing)
    let phases: [Any?] = [takeoff, climb, cruise, descent, approach, landing]
    guard phases.contains(where: { $0 != nil }) else { return nil }
    return Performance(
      takeoff: takeoff,
      climb: climb,
      cruise: cruise,
      descent: descent,
      approach: approach,
      landing: landing
    )
  }

  private static func takeoff(from t: APDRecord.Performance.Takeoff) -> Performance.Takeoff? {
    if t.v2Kt == nil && t.distanceFt == nil { return nil }
    return Performance.Takeoff(v2Kt: t.v2Kt, distanceFt: t.distanceFt)
  }

  private static func climb(from c: APDRecord.Performance.Climb) -> Performance.Climb? {
    let initial = climbBand(IAS: c.initialIASKt, rateOfClimb: c.initialRateOfClimbFPM)
    let toFL150 = climbBand(IAS: c.to150IASKt, rateOfClimb: c.to150RateOfClimbFPM)
    let toFL240 = climbBand(IAS: c.to240IASKt, rateOfClimb: c.to240RateOfClimbFPM)
    if initial == nil && toFL150 == nil && toFL240 == nil && c.machClimbMach == nil {
      return nil
    }
    return Performance.Climb(
      initialClimb: initial,
      toFL150: toFL150,
      toFL240: toFL240,
      machClimb: c.machClimbMach
    )
  }

  private static func climbBand(IAS: Double?, rateOfClimb: Double?) -> Performance.ClimbBand? {
    guard let IAS, let rateOfClimb else { return nil }
    return Performance.ClimbBand(IASKt: IAS, rateOfClimbFPM: rateOfClimb)
  }

  private static func cruise(from c: APDRecord.Performance.Cruise) -> Performance.Cruise? {
    if c.TASKt == nil && c.mach == nil && c.ceilingFL == nil && c.rangeNmi == nil { return nil }
    return Performance.Cruise(
      TASKt: c.TASKt,
      mach: c.mach,
      ceilingFL: c.ceilingFL,
      rangeNmi: c.rangeNmi
    )
  }

  private static func descent(from d: APDRecord.Performance.Descent) -> Performance.Descent? {
    let initial = descentBand(IAS: d.initialIASKt, rateOfDescent: d.initialRateOfDescentFPM)
    let normal = descentBand(IAS: d.descentIASKt, rateOfDescent: d.descentRateOfDescentFPM)
    if initial == nil && normal == nil { return nil }
    return Performance.Descent(initialDescent: initial, descent: normal)
  }

  private static func descentBand(IAS: Double?, rateOfDescent: Double?) -> Performance.DescentBand?
  {
    guard let IAS, let rateOfDescent else { return nil }
    return Performance.DescentBand(IASKt: IAS, rateOfDescentFPM: rateOfDescent)
  }

  private static func approach(from a: APDRecord.Performance.Approach) -> Performance.Approach? {
    if a.IASKt == nil && a.minimumCleanSpeedKt == nil && a.rateOfDescentFPM == nil { return nil }
    return Performance.Approach(
      IASKt: a.IASKt,
      minimumCleanSpeedKt: a.minimumCleanSpeedKt,
      rateOfDescentFPM: a.rateOfDescentFPM
    )
  }

  private static func landing(from l: APDRecord.Performance.Landing) -> Performance.Landing? {
    if l.vatKt == nil && l.distanceFt == nil { return nil }
    return Performance.Landing(vatKt: l.vatKt, distanceFt: l.distanceFt)
  }
}
