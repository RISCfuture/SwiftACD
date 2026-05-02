import Foundation

/// Visual-recognition cues published by EUROCONTROL — wing position, engine
/// position, tail configuration, landing-gear configuration. Every field
/// holds the EUROCONTROL phrase verbatim.
///
/// The well-known "no value" sentinels (`""`, `"-"`, `"No"`, `"No data"`,
/// `"N/A"`) are normalized to `nil` at parse time.
public struct Recognition: Sendable, Codable, Hashable {

  /// Vertical position of the main wing on the fuselage. Examples:
  /// `"Low wing"`, `"High wing (wing struts)"`,
  /// `"Low swept wing (Raked wings)"`, `"Mid wing with canard front wing"`,
  /// `"Delta wing"`, `"Biplane"`, `"Four-blade main rotor"`.
  public let wing: String?

  /// Where the powerplant is mounted on the airframe. Examples:
  /// `"Underwing mounted"`, `"(Front) Wing leading mounted"`,
  /// `"Both sides of rear fuselage"`, `"In fuselage"`, `"Above cabin"`,
  /// `"Behind cabin"`, `"Nose mounted and behind cabin"`.
  public let engine: String?

  /// Horizontal-stabilizer arrangement. Examples: `"Regular tail, mid set"`,
  /// `"T-tail"`, `"Cruciform tail"`, `"Butterfly tail"`,
  /// `"Booms with twin fins"`, `"Double fin, low set"`,
  /// `"Two-blade tail rotor"`, `"No tail plane"`.
  public let tail: String?

  /// Landing-gear arrangement. Examples: `"Tricycle retractable"`,
  /// `"Tricycle fixed"`, `"Tailwheel fixed"`, `"Tailwheel retractable"`,
  /// `"Skids"`, `"Quadricycle retractable"`, `"Amphibian"`,
  /// `"Tricycle retractable/Floats fixed"`.
  public let landingGear: String?

  /// Memberwise initializer. All fields default to `nil`.
  public init(
    wing: String? = nil,
    engine: String? = nil,
    tail: String? = nil,
    landingGear: String? = nil
  ) {
    self.wing = wing
    self.engine = engine
    self.tail = tail
    self.landingGear = landingGear
  }
}
