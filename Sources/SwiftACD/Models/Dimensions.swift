public import Foundation

/// Physical dimensions of an aircraft type.
///
/// All quantities are stored as raw scalars in feet and exposed as
/// `Measurement<UnitLength>` computed properties. The FAA Aircraft
/// Characteristics Database is the preferred source; EUROCONTROL APD fills in
/// when ACD has no value.
public struct Dimensions: Sendable, Codable, Hashable {

  /// Wingspan, in feet. This is the FAA's wingspan without winglets or
  /// sharklets, falling back to the winglet-equipped span when the FAA
  /// publishes only that, and to EUROCONTROL when the FAA has no value.
  public let wingspanFt: Double

  /// Overall length, in feet.
  public let lengthFt: Double

  /// Tail (overall) height, in feet.
  public let tailHeightFt: Double

  /// Wingspan with winglets or sharklets fitted, in feet. `nil` unless the
  /// FAA publishes a winglet-equipped span for the type; the FAA records both
  /// configurations for types offered either way (e.g. `B738`).
  public let wingspanWithWingletsFt: Double?

  /// Wingspan as a `Measurement`. Convert to other units with
  /// `wingspan.converted(to: .meters)`.
  public var wingspan: Measurement<UnitLength> {
    .init(value: wingspanFt, unit: .feet)
  }

  /// Wingspan with winglets or sharklets as a `Measurement`, or `nil` when
  /// the FAA publishes no winglet-equipped span.
  public var wingspanWithWinglets: Measurement<UnitLength>? {
    wingspanWithWingletsFt.map { .init(value: $0, unit: .feet) }
  }

  /// Overall length as a `Measurement`.
  public var length: Measurement<UnitLength> {
    .init(value: lengthFt, unit: .feet)
  }

  /// Tail (overall) height as a `Measurement`.
  public var tailHeight: Measurement<UnitLength> {
    .init(value: tailHeightFt, unit: .feet)
  }

  /// Memberwise initializer.
  ///
  /// - Parameters:
  ///   - wingspanFt: Maximum wingspan, in feet.
  ///   - lengthFt: Overall length, in feet.
  ///   - tailHeightFt: Tail (overall) height, in feet.
  ///   - wingspanWithWingletsFt: Wingspan with winglets or sharklets fitted,
  ///     in feet.
  public init(
    wingspanFt: Double,
    lengthFt: Double,
    tailHeightFt: Double,
    wingspanWithWingletsFt: Double? = nil
  ) {
    self.wingspanFt = wingspanFt
    self.lengthFt = lengthFt
    self.tailHeightFt = tailHeightFt
    self.wingspanWithWingletsFt = wingspanWithWingletsFt
  }
}
