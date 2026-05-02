import Foundation

/// Physical dimensions of an aircraft type.
///
/// All quantities are stored as raw scalars in feet and exposed as
/// `Measurement<UnitLength>` computed properties. The FAA Aircraft
/// Characteristics Database is the preferred source; EUROCONTROL APD fills in
/// when ACD has no value.
public struct Dimensions: Sendable, Codable, Hashable {

  /// Maximum wingspan, in feet.
  public let wingspanFt: Double

  /// Overall length, in feet.
  public let lengthFt: Double

  /// Tail (overall) height, in feet.
  public let tailHeightFt: Double

  /// Wingspan as a `Measurement`. Convert to other units with
  /// `wingspan.converted(to: .meters)`.
  public var wingspan: Measurement<UnitLength> {
    .init(value: wingspanFt, unit: .feet)
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
  public init(wingspanFt: Double, lengthFt: Double, tailHeightFt: Double) {
    self.wingspanFt = wingspanFt
    self.lengthFt = lengthFt
    self.tailHeightFt = tailHeightFt
  }
}
