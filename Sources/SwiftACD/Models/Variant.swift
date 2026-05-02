import Foundation

/// One row of the FAA Aircraft Characteristics Database, exposed publicly so
/// callers can introspect every variant under an ICAO type designator.
///
/// Multiple `Variant`s exist for one ICAO type when the spreadsheet records
/// distinct configurations (e.g. winglets vs. no winglets, freighter vs.
/// passenger). The aggregated, top-level fields on ``AircraftProfile`` come
/// from the first variant; consumers that care about a specific configuration
/// should iterate ``AircraftProfile/variants``.
public struct Variant: Sendable, Codable, Hashable, Identifiable {

  /// Stable identifier for this variant within a profile. Synthesized as
  /// `"\(ICAO)#\(index)"` because the FAA workbook does not assign IDs.
  public let id: String

  /// Manufacturer name as written in the FAA row (may differ in casing /
  /// spelling from the canonical Identity manufacturer).
  public let manufacturer: String?

  /// Model / variant name as written in the FAA row.
  public let model: String?

  /// Approach speed (Vref) as written in the FAA row, in knots.
  public let approachSpeedKt: Double?

  /// Physical dimensions for this specific variant. `nil` when no dimension
  /// fields were populated on the row.
  public let dimensions: Dimensions?

  /// Weight and gear-geometry fields for this specific variant. `nil` when
  /// the row has no MTOW.
  public let weights: Weights?

  /// FAA-published categories for this specific variant. EUROCONTROL-only
  /// fields (``Categories/wakeTurbulence``, ``Categories/RECAT_EU``) are
  /// always `nil` here — those live on ``AircraftProfile/categories``.
  public let categories: Categories

  /// Approach speed as a `Measurement`, or `nil` when the FAA row omits it.
  public var approachSpeed: Measurement<UnitSpeed>? {
    approachSpeedKt.map { .init(value: $0, unit: .knots) }
  }

  /// Memberwise initializer.
  public init(
    id: String,
    manufacturer: String?,
    model: String?,
    approachSpeedKt: Double?,
    dimensions: Dimensions?,
    weights: Weights?,
    categories: Categories
  ) {
    self.id = id
    self.manufacturer = manufacturer
    self.model = model
    self.approachSpeedKt = approachSpeedKt
    self.dimensions = dimensions
    self.weights = weights
    self.categories = categories
  }
}
