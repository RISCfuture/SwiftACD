# Changelog

All notable changes to SwiftACD will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed (breaking)

- `Performance.Descent.initialDescent` is now a `Performance.MachDescentBand`
  rather than a `DescentBand`. EUROCONTROL publishes the initial descent as a
  Mach number and a rate of descent, never as an IAS, so the band the model
  asked for could never be assembled and the field was always `nil`.

### Added

- `Dimensions.wingspanWithWinglets` (and its `wingspanWithWingletsFt` scalar)
  expose the FAA's winglet/sharklet wingspan column, which the parser
  previously ignored.

### Fixed

- The EUROCONTROL index page (`apd/listpage.html`) is no longer parsed as an
  aircraft detail page, so the profile dictionary no longer contains an empty
  entry keyed `listpage`.
- Types whose FAA row fills in only the winglet-equipped wingspan column (for
  example `GLF6` and the E-Jets) no longer report a wingspan of 0 ft;
  `Dimensions.wingspan` falls back to that column before falling back to
  EUROCONTROL.

## [0.2.1] - 2026-09-14

### Changed

- Raised the minimum dependency versions to SwiftSoup 2.13.7,
  swift-argument-parser 1.8.2, and swift-docc-plugin 1.5.0.
- The package now declares Swift language mode 5 alongside mode 6, so a package
  that has not moved to mode 6 can still depend on SwiftACD. The required Swift
  tools version is unchanged at 6.3.

### Fixed

- Documentation: the Domain Enums topic no longer links to `WingPosition`,
  `EnginePosition`, `TailConfiguration`, or `LandingGearConfiguration`, which
  the library does not define — `Recognition` exposes those fields as `String?`.
  `Parser.init(directory:)` links to `Downloader.downloadAll(errorCallback:)`
  with its argument label, so the symbol resolves.

## [0.2.0] - 2026-07-06

### Added

- Linux support. `URLSession` is guarded behind `FoundationNetworking`, a
  `String(localized:)` shim covers error strings, and the downloader falls back
  to a buffered response on Linux (Apple keeps incremental progress streaming).

## [0.1.0] - 2026-05-01

### Added

- Initial release.
- Async `Downloader` that fetches the FAA ACD `.xlsx` and scrapes the EUROCONTROL APD detail pages.
- `Parser` that ingests the downloaded data and assembles one `AircraftProfile` per ICAO type designator.
- Domain-restricted enums for every fixed-value field (no open `String` types).
- `Measurement<Unit>` computed properties for every physical quantity.
- `AsyncProgress` actor for tracking parse progress.
- `SwiftACDError` with localized error descriptions.

### Changed

- Adopted the Approachable Concurrency upcoming-feature flags (`NonisolatedNonsendingByDefault`, `InferIsolatedConformances`). The `nonisolated async` APIs (`Parser.parse`, `Downloader.downloadACD`/`downloadAPD`/`downloadAll`) run on the caller's executor by default instead of hopping to the global concurrent executor.
- Raised the minimum deployment targets to macOS 15, iOS 18, tvOS 18, watchOS 11, and visionOS 2, and moved shared-state synchronization to `Synchronization.Mutex`.
