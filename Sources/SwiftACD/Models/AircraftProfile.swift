import Foundation

/// A composite aircraft-type profile assembled from the FAA Aircraft
/// Characteristics Database (ACD) and the EUROCONTROL Aircraft Performance
/// Database (APD).
///
/// One ``AircraftProfile`` exists per ICAO type designator. Top-level fields
/// follow a **prefer-FAA, fall back to APD** rule for overlapping data; FAA-
/// only and APD-only fields come from their authoritative source. Every
/// matching ACD row is preserved in ``variants`` so callers can address
/// individual configurations (e.g. winglets vs. no winglets).
public struct AircraftProfile: Sendable, Codable, Hashable, Identifiable {

  /// ICAO aircraft type designator. Same as ``Identity/ICAOTypeDesignator``.
  public var id: String { identity.ICAOTypeDesignator }

  /// Naming, classification, and powerplant fields keyed by ICAO type
  /// designator.
  public let identity: Identity

  /// Airport- and operations-design classifications (AAC, ADG, TDG, WTC,
  /// RECAT-EU).
  public let categories: Categories

  /// Physical dimensions (wingspan, length, tail height). `nil` when neither
  /// source published any dimension.
  public let dimensions: Dimensions?

  /// Weight and gear-geometry fields. `nil` when neither source published an
  /// MTOW.
  public let weights: Weights?

  /// Visual-recognition cues (wing/engine/tail/landing-gear). APD-only;
  /// `nil` when the APD page is absent or sparse.
  public let recognition: Recognition?

  /// Flight-performance envelope (take-off, climb, cruise, descent, approach,
  /// landing). APD-only; `nil` when the APD page is absent or sparse.
  public let performance: Performance?

  /// Every FAA ACD row that matched this ICAO designator. May be empty for an
  /// APD-only profile. Top-level scalar fields are summarized from the first
  /// variant — iterate this array to address a specific configuration.
  public let variants: [Variant]

  /// Which sources contributed to this profile.
  public let sources: Source

  /// Memberwise initializer. Most callers should obtain ``AircraftProfile``
  /// values from ``Parser/parse(progress:errorCallback:)`` rather than
  /// constructing them directly; this initializer exists to enable testing
  /// and round-tripping through `Codable`.
  public init(
    identity: Identity,
    categories: Categories,
    dimensions: Dimensions?,
    weights: Weights?,
    recognition: Recognition?,
    performance: Performance?,
    variants: [Variant],
    sources: Source
  ) {
    self.identity = identity
    self.categories = categories
    self.dimensions = dimensions
    self.weights = weights
    self.recognition = recognition
    self.performance = performance
    self.variants = variants
    self.sources = sources
  }
}

/// Bitmask of the data sources that contributed to a profile.
///
/// Inspect via ``Source/contains(_:)`` (e.g. `profile.sources.contains(.ACD)`)
/// or use direct equality (`profile.sources == [.ACD, .APD]`).
public struct Source: OptionSet, Sendable, Codable, Hashable {

  /// FAA Aircraft Characteristics Database.
  public static let ACD = Self(rawValue: 1 << 0)

  /// EUROCONTROL Aircraft Performance Database.
  public static let APD = Self(rawValue: 1 << 1)

  /// Raw bitmask value backing the option set.
  public let rawValue: UInt8

  /// Construct a ``Source`` from a raw bitmask. Prefer the named statics
  /// (``ACD``, ``APD``) when constructing values directly.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }
}
