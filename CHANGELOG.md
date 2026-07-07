# Changelog

All notable changes to SwiftACD will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
