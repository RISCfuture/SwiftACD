# SwiftACD: Composite aircraft profile library

SwiftACD assembles a single composite profile per ICAO aircraft type designator
by combining two public datasets — the
[FAA Aircraft Characteristics Database (ACD)](https://www.faa.gov/airports/engineering/aircraft_char_database)
and the
[EUROCONTROL Aircraft Performance Database (APD)](https://learningzone.eurocontrol.int/ilp/customs/ATCPFDB/default.aspx).
The two sources are complementary: the FAA ACD owns U.S. airport-design fields
(approach category, design groups, MTOW, gear geometry), while EUROCONTROL APD
owns identity metadata, RECAT-EU/WTC classifications, and the full takeoff
through landing performance envelope. SwiftACD downloads, parses, and folds
both into one queryable dictionary keyed by ICAO type designator (`B738`,
`A320`, `C172`, …).

## Requirements

- Swift 6.3+
- macOS 13+, iOS 16+, watchOS 9+, tvOS 16+, or visionOS 1+

## Installation

Add SwiftACD to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/RISCfuture/SwiftACD", branch: "main")
]
```

Then list it as a dependency of your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["SwiftACD"]
)
```

## Quickstart

### 1. Download both sources

```swift
import SwiftACD

let downloader = try Downloader()
let directory = try await downloader.downloadAll()
```

`downloadAll()` writes the FAA `.xlsx` to the working-directory root and the
EUROCONTROL detail pages under an `apd/` subdirectory. If you want to manage
the directory yourself, pass a `workingDirectory:` URL to the initializer.

### 2. Parse the downloaded data

```swift
let parser = Parser(directory: directory)
let progress = AsyncProgress()
let profiles = try await parser.parse(
    progress: progress,
    errorCallback: { error in
        // Per-record errors. The row/page is skipped; parsing continues.
        print("skipped:", error.localizedDescription)
    }
)
```

The result is a `[String: AircraftProfile]` keyed by ICAO type designator.

### 3. Look up an aircraft and read typed fields

```swift
guard let b738 = profiles["B738"] else { return }

print(b738.identity.manufacturer ?? "?", b738.identity.model ?? "?")

if let dims = b738.dimensions {
    let span = dims.wingspan.converted(to: .meters)
    print("Wingspan: \(span)")
}

if let cruise = b738.performance?.cruise, let tas = cruise.tas {
    print("Cruise TAS: \(tas), Mach \(cruise.mach ?? 0)")
}

print("Variants:", b738.variants.count)        // winglets vs. no winglets, …
print("Sources:", b738.sources)                 // .acd, .apd, or both
```

## Sources

- **FAA Aircraft Characteristics Database** — single `.xlsx` workbook at
  <https://www.faa.gov/airports/engineering/aircraft_char_database>.
- **EUROCONTROL Aircraft Performance Database** — HTML detail pages at
  <https://learningzone.eurocontrol.int/ilp/customs/ATCPFDB/default.aspx>.

> **EUROCONTROL APD copyright notice.** The APD landing page states that
> "Copyright permission must be sought from EUROCONTROL." SwiftACD only
> enables programmatic access to the data; it does **not** grant any
> redistribution rights. Downstream consumers are responsible for obtaining
> their own copyright permission directly from EUROCONTROL before
> redistributing, republishing, or otherwise reusing APD content. The FAA
> ACD is U.S. Government work and not subject to the same restriction.

## Composite profile design

- **One `AircraftProfile` per ICAO type designator.** Both sources are keyed by
  ICAO Doc 8643 type designator, so the join is exact.
- **Every FAA row is preserved.** The FAA spreadsheet often records multiple
  rows for the same designator (e.g. `B738` with and without winglets). All of
  them are exposed through `AircraftProfile.variants` so callers can address a
  specific configuration.
- **Conflict resolution: prefer FAA, fall back to APD.** For fields that both
  sources publish (manufacturer, model, wingspan, length, tail height, MTOW,
  approach category), the top-level field comes from the first FAA row and
  falls back to APD only when FAA omits the value.
- **`sources` tells you the lineage.** Each profile's `sources` `OptionSet`
  contains `.acd`, `.apd`, or both, so callers can quickly tell whether a
  profile was assembled from full data or from only one side.

## Measurement convention

Every physical quantity is stored as a raw `Double` in a fixed source unit
(feet, pounds, knots, feet-per-minute, nautical miles) and exposed as a
Foundation `Measurement<UnitX>` computed property. Convert to whatever unit
you need with `.converted(to:)`:

```swift
let wingspanMeters = b738.dimensions?.wingspan.converted(to: .meters)
let mtowKilograms  = b738.weights?.mtow.converted(to: .kilograms)
let tasKmh         = b738.performance?.cruise.tas?.converted(to: .kilometersPerHour)
```

Mach numbers are dimensionless and exposed as `Double` (Foundation has no
`UnitMach`).

## Documentation

DocC documentation is provided. Run `swift package generate-documentation
--target SwiftACD` to produce a doc archive at
`.build/plugins/Swift-DocC/outputs/SwiftACD.doccarchive`, or use **Product →
Build Documentation** from within Xcode.

## License

SwiftACD is released under the MIT License. See [LICENSE](LICENSE). The MIT
License covers only the SwiftACD source; data obtained through the library
is governed by its publisher's terms (see the EUROCONTROL notice above).

## Credits

Aircraft characteristics data from the U.S. Federal Aviation Administration
(FAA). Aircraft performance data from EUROCONTROL.
