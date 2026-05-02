import Foundation

/// Weight and gear-geometry fields.
///
/// `mtow` is preferred from the FAA Aircraft Characteristics Database; if FAA
/// has no value, EUROCONTROL APD is the fallback. `mainGearWidth` and
/// `cockpitToMainGear` are FAA-only — APD does not publish them.
public struct Weights: Sendable, Codable, Hashable {

  /// Maximum take-off weight, in pounds.
  public let MTOWLb: Double

  /// Main-gear width (outer to outer), in feet. FAA-only.
  public let mainGearWidthFt: Double?

  /// Cockpit-to-main-gear distance, in feet. FAA-only.
  public let cockpitToMainGearFt: Double?

  /// MTOW as a `Measurement`. Convert with `MTOW.converted(to: .kilograms)`.
  public var MTOW: Measurement<UnitMass> {
    .init(value: MTOWLb, unit: .pounds)
  }

  /// Main-gear width as a `Measurement`, or `nil` when FAA omits it.
  public var mainGearWidth: Measurement<UnitLength>? {
    mainGearWidthFt.map { .init(value: $0, unit: .feet) }
  }

  /// Cockpit-to-main-gear distance as a `Measurement`, or `nil` when FAA
  /// omits it.
  public var cockpitToMainGear: Measurement<UnitLength>? {
    cockpitToMainGearFt.map { .init(value: $0, unit: .feet) }
  }

  /// Memberwise initializer.
  ///
  /// - Parameters:
  ///   - MTOWLb: Maximum take-off weight, in pounds.
  ///   - mainGearWidthFt: Main-gear width, in feet (FAA-only; defaults to
  ///     `nil`).
  ///   - cockpitToMainGearFt: Cockpit-to-main-gear distance, in feet
  ///     (FAA-only; defaults to `nil`).
  public init(
    MTOWLb: Double,
    mainGearWidthFt: Double? = nil,
    cockpitToMainGearFt: Double? = nil
  ) {
    self.MTOWLb = MTOWLb
    self.mainGearWidthFt = mainGearWidthFt
    self.cockpitToMainGearFt = cockpitToMainGearFt
  }
}
