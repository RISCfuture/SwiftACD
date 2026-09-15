# Changelog

All notable changes to SwiftACD will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed (breaking)

- Progress reporting now uses Foundation's `ProgressManager` (SF-0023) instead
  of SwiftACD's own `Progress` struct. The data flow is inverted: rather than the
  callee publishing snapshots *up* through a closure, the caller passes a
  `Subprogress` *down*.
  - `Parser.parse(progress:errorCallback:)` takes
    `progress: consuming Subprogress? = nil` in place of `AsyncProgress?`.
  - `Downloader`'s progress sink moved off the initializer and onto each method:
    `downloadACD(progress:)`, `downloadAPD(progress:errorCallback:)`, and
    `downloadAll(progress:errorCallback:)` each accept a
    `consuming Subprogress?`. `Downloader.init` no longer takes a
    `progressCallback:`.
  - `Progress`, `AsyncProgress`, and `ProgressCallback` are removed. Read
    `completedCount`, `fractionCompleted`, and `isFinished` from your own
    `ProgressManager`, which is `Observable` — so progress can be followed with
    `Observations.untilFinished` rather than polled on a timer.
- Raised the minimum deployment targets to macOS 27, iOS 27, tvOS 27, watchOS 27,
  and visionOS 27, and the package tools-version to 6.4. `ProgressManager` has no
  lower availability annotation, and `MacOSVersion.v27` requires
  `_PackageDescription 6.4`.

### Added

- EUROCONTROL APD parsing now reports progress per detail page, weighted by each
  page's byte size. Previously the whole APD leg jumped from 0% to 100% in a
  single step when it finished.
- Downloads and parses publish `totalByteCount`/`completedByteCount` and, where
  the unit of work is a page, `totalFileCount`/`completedFileCount`, so a
  progress UI can show byte and file counts alongside the fraction. These are
  recorded on leaf managers only, since `summary(of:)` sums the whole subtree.

### Removed

- The Swift 6.3 and macOS 15 / macOS 26 CI legs. The macOS 27 SDK is only
  available on GitHub's `xcode-27` image, and `ProgressManager` is
  `@available(FoundationPreview 6.4)` on Linux so the 6.3 Linux toolchain cannot
  build the package.

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
