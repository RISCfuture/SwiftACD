import Foundation

/// Flight-performance envelope as published by the EUROCONTROL Aircraft
/// Performance Database. Every phase is optional because EUROCONTROL omits
/// the phases that do not apply to a given aircraft (e.g. helicopters do not
/// report a Mach climb).
///
/// All scalar quantities are stored in fixed source units and exposed as
/// `Measurement<UnitX>` computed properties. `mach` values are dimensionless
/// `Double`s — Foundation has no `UnitMach`.
public struct Performance: Sendable, Codable, Hashable {

  /// Take-off phase (V₂, distance). `nil` when EUROCONTROL omits it.
  public let takeoff: Takeoff?

  /// Climb-phase IAS / ROC bands. `nil` when EUROCONTROL publishes no climb
  /// data.
  public let climb: Climb?

  /// Cruise envelope (TAS, Mach, ceiling, range). `nil` when EUROCONTROL
  /// omits it.
  public let cruise: Cruise?

  /// Descent IAS / ROD bands. `nil` when EUROCONTROL omits descent data.
  public let descent: Descent?

  /// Approach phase (minimum clean speed, ROD). `nil` when EUROCONTROL
  /// omits it.
  public let approach: Approach?

  /// Landing phase (Vat, distance). `nil` when EUROCONTROL omits it.
  public let landing: Landing?

  /// Memberwise initializer. All phases default to `nil`.
  public init(
    takeoff: Takeoff? = nil,
    climb: Climb? = nil,
    cruise: Cruise? = nil,
    descent: Descent? = nil,
    approach: Approach? = nil,
    landing: Landing? = nil
  ) {
    self.takeoff = takeoff
    self.climb = climb
    self.cruise = cruise
    self.descent = descent
    self.approach = approach
    self.landing = landing
  }
}

extension Performance {

  /// Take-off performance.
  public struct Takeoff: Sendable, Codable, Hashable {
    /// V₂ (take-off safety speed) as IAS in knots.
    public let v2Kt: Double?
    /// Take-off distance, in feet.
    public let distanceFt: Double?

    /// V₂ as a `Measurement`, or `nil` when not published.
    public var v2: Measurement<UnitSpeed>? { v2Kt.map { .init(value: $0, unit: .knots) } }

    /// Take-off distance as a `Measurement`, or `nil` when not published.
    public var distance: Measurement<UnitLength>? {
      distanceFt.map { .init(value: $0, unit: .feet) }
    }

    /// Memberwise initializer.
    public init(v2Kt: Double? = nil, distanceFt: Double? = nil) {
      self.v2Kt = v2Kt
      self.distanceFt = distanceFt
    }
  }

  /// Climb performance, broken into the bands EUROCONTROL publishes.
  public struct Climb: Sendable, Codable, Hashable {
    /// Initial climb (typically below FL100).
    public let initialClimb: ClimbBand?
    /// Climb to FL150 (15,000 ft).
    public let toFL150: ClimbBand?
    /// Climb to FL240 (24,000 ft).
    public let toFL240: ClimbBand?
    /// Mach used during the Mach-climb band. Dimensionless.
    public let machClimb: Double?

    /// Memberwise initializer. All fields default to `nil`.
    public init(
      initialClimb: ClimbBand? = nil,
      toFL150: ClimbBand? = nil,
      toFL240: ClimbBand? = nil,
      machClimb: Double? = nil
    ) {
      self.initialClimb = initialClimb
      self.toFL150 = toFL150
      self.toFL240 = toFL240
      self.machClimb = machClimb
    }
  }

  /// IAS + ROC pair recorded for one climb band.
  public struct ClimbBand: Sendable, Codable, Hashable {
    /// Indicated airspeed, in knots.
    public let IASKt: Double
    /// Rate of climb, in feet per minute.
    public let rateOfClimbFPM: Double

    /// IAS as a `Measurement`.
    public var IAS: Measurement<UnitSpeed> { .init(value: IASKt, unit: .knots) }
    /// Rate of climb. Foundation lacks a vertical-speed unit, so this is a
    /// `UnitSpeed` expressed in feet per minute via `UnitSpeed.feetPerMinute`.
    public var rateOfClimb: Measurement<UnitSpeed> {
      .init(value: rateOfClimbFPM, unit: .feetPerMinute)
    }

    /// Memberwise initializer.
    public init(IASKt: Double, rateOfClimbFPM: Double) {
      self.IASKt = IASKt
      self.rateOfClimbFPM = rateOfClimbFPM
    }
  }

  /// Cruise performance.
  public struct Cruise: Sendable, Codable, Hashable {
    /// True airspeed, in knots.
    public let TASKt: Double?
    /// Cruise Mach. Dimensionless.
    public let mach: Double?
    /// Service ceiling, expressed as an ICAO flight level (e.g. `390` for
    /// FL 390). Flight levels are pressure altitudes referenced to the
    /// 1013.25 hPa standard datum, not geometric altitudes, so no
    /// `Measurement<UnitLength>` view is offered — the value cannot be
    /// converted to feet without knowing the local altimeter setting.
    public let ceilingFL: Int?
    /// Range, in nautical miles.
    public let rangeNmi: Double?

    /// True airspeed as a `Measurement`, or `nil` when not published.
    public var TAS: Measurement<UnitSpeed>? { TASKt.map { .init(value: $0, unit: .knots) } }
    /// Range as a `Measurement`, or `nil` when not published.
    public var range: Measurement<UnitLength>? {
      rangeNmi.map { .init(value: $0, unit: .nauticalMiles) }
    }

    /// Memberwise initializer. All fields default to `nil`.
    public init(
      TASKt: Double? = nil,
      mach: Double? = nil,
      ceilingFL: Int? = nil,
      rangeNmi: Double? = nil
    ) {
      self.TASKt = TASKt
      self.mach = mach
      self.ceilingFL = ceilingFL
      self.rangeNmi = rangeNmi
    }
  }

  /// Descent performance.
  public struct Descent: Sendable, Codable, Hashable {
    /// Initial descent band (high-altitude / Mach descent prior to crossing
    /// FL240).
    public let initialDescent: DescentBand?
    /// Standard descent band (post FL240, IAS-driven).
    public let descent: DescentBand?

    /// Memberwise initializer. Both fields default to `nil`.
    public init(initialDescent: DescentBand? = nil, descent: DescentBand? = nil) {
      self.initialDescent = initialDescent
      self.descent = descent
    }
  }

  /// IAS + ROD pair recorded for one descent band.
  public struct DescentBand: Sendable, Codable, Hashable {
    /// Indicated airspeed, in knots.
    public let IASKt: Double
    /// Rate of descent, in feet per minute.
    public let rateOfDescentFPM: Double

    /// IAS as a `Measurement`.
    public var IAS: Measurement<UnitSpeed> { .init(value: IASKt, unit: .knots) }
    /// Rate of descent expressed via `UnitSpeed.feetPerMinute`.
    public var rateOfDescent: Measurement<UnitSpeed> {
      .init(value: rateOfDescentFPM, unit: .feetPerMinute)
    }

    /// Memberwise initializer.
    public init(IASKt: Double, rateOfDescentFPM: Double) {
      self.IASKt = IASKt
      self.rateOfDescentFPM = rateOfDescentFPM
    }
  }

  /// Approach performance.
  public struct Approach: Sendable, Codable, Hashable {
    /// Indicated airspeed during approach, in knots. EUROCONTROL labels this
    /// the "approach IAS"; it is the recommended IAS prior to crossing the
    /// final approach fix.
    public let IASKt: Double?
    /// Minimum clean speed, in knots IAS.
    public let minimumCleanSpeedKt: Double?
    /// Rate of descent, in feet per minute.
    public let rateOfDescentFPM: Double?

    /// Approach IAS as a `Measurement`, or `nil` when not published.
    public var IAS: Measurement<UnitSpeed>? { IASKt.map { .init(value: $0, unit: .knots) } }
    /// Minimum clean speed as a `Measurement`, or `nil` when not published.
    public var minimumCleanSpeed: Measurement<UnitSpeed>? {
      minimumCleanSpeedKt.map { .init(value: $0, unit: .knots) }
    }
    /// Rate of descent as a `Measurement` (via `UnitSpeed.feetPerMinute`),
    /// or `nil` when not published.
    public var rateOfDescent: Measurement<UnitSpeed>? {
      rateOfDescentFPM.map { .init(value: $0, unit: .feetPerMinute) }
    }

    /// Memberwise initializer. All fields default to `nil`.
    public init(
      IASKt: Double? = nil,
      minimumCleanSpeedKt: Double? = nil,
      rateOfDescentFPM: Double? = nil
    ) {
      self.IASKt = IASKt
      self.minimumCleanSpeedKt = minimumCleanSpeedKt
      self.rateOfDescentFPM = rateOfDescentFPM
    }
  }

  /// Landing performance.
  public struct Landing: Sendable, Codable, Hashable {
    /// Vat (1.3 × Vso at MLW) in knots IAS.
    public let vatKt: Double?
    /// Landing distance, in feet.
    public let distanceFt: Double?

    /// Vat as a `Measurement`, or `nil` when not published.
    public var vat: Measurement<UnitSpeed>? { vatKt.map { .init(value: $0, unit: .knots) } }
    /// Landing distance as a `Measurement`, or `nil` when not published.
    public var distance: Measurement<UnitLength>? {
      distanceFt.map { .init(value: $0, unit: .feet) }
    }

    /// Memberwise initializer. Both fields default to `nil`.
    public init(vatKt: Double? = nil, distanceFt: Double? = nil) {
      self.vatKt = vatKt
      self.distanceFt = distanceFt
    }
  }
}

extension UnitSpeed {
  /// Feet per minute. Useful for vertical speeds (climb/descent rates).
  ///
  /// Coefficient is derived from Foundation's exact ft↔m conversion divided
  /// by sixty seconds per minute, so we never hand-roll a meters-per-second
  /// constant.
  public static let feetPerMinute = UnitSpeed(
    symbol: "fpm",
    converter: UnitConverterLinear(
      coefficient: Measurement(value: 1, unit: UnitLength.feet)
        .converted(to: .meters).value / 60.0
    )
  )
}
