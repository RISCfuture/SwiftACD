# Data Sources and Field Provenance

A field-by-field map of where each piece of an ``AircraftProfile`` comes from,
the rule used to resolve overlap, and the redistribution caveat that applies
to EUROCONTROL data.

## Overview

SwiftACD merges two independently-maintained public datasets into one
composite record per ICAO Doc 8643 type designator. The two sources are
deliberately complementary:

| Source | Scope | Authority |
|---|---|---|
| **FAA Aircraft Characteristics Database** (ACD) | U.S. airport-design grouping: approach category, airplane/taxiway design groups, MTOW, main-gear geometry, approach speed, basic dimensions. May publish multiple rows for one ICAO when several airframe variants exist. | <https://www.faa.gov/airports/engineering/aircraft_char_database> |
| **EUROCONTROL Aircraft Performance Database** (APD) | Identity (manufacturer/model/IATA codes/aircraft class/engine type and count), wake turbulence (WTC), RECAT-EU separation category, visual recognition (wing/engine/tail/landing-gear configuration), and the full flight-performance envelope (takeoff/climb/cruise/descent/approach/landing). | <https://learningzone.eurocontrol.int/ilp/customs/ATCPFDB/default.aspx> |

The two datasets overlap on a small set of fields: manufacturer name, model
name, wingspan, length, tail height, MTOW, and approach category. Everything
else belongs cleanly to one source.

## Conflict resolution rule

For any field both sources publish, SwiftACD **prefers FAA and falls back to
APD**:

```
field = primaryFAARow.field ?? apdRecord.field
```

The "primary FAA row" is the first row matching the ICAO designator in the
FAA workbook. The rationale is twofold:

1. The FAA spreadsheet is a single authoritative file maintained for U.S.
   airport-design use; values are normalized to consistent units.
2. APD is published as HTML and aggregated from multiple sources of varying
   precision; using it only as a fallback minimizes the chance of a unit or
   rounding mismatch surfacing in the composite.

When you need to inspect the lineage, ``AircraftProfile/sources`` is an
``Source`` `OptionSet` containing `.ACD`, `.APD`, or both. To see all FAA
variants under one ICAO, iterate ``AircraftProfile/variants``.

## Variant fan-out

The FAA workbook commonly publishes multiple rows for a single ICAO
designator (for example, `B738` is recorded both with and without winglets,
and freighter variants are recorded separately from passenger variants).
SwiftACD preserves every row in ``AircraftProfile/variants``: each entry is a
``Variant`` with the full FAA-row payload (manufacturer, model, dimensions,
weights, categories, approach speed). The aggregated top-level fields on
``AircraftProfile`` come from the first variant; consumers that care about a
specific configuration should iterate ``AircraftProfile/variants`` directly.

## Field-by-field provenance

### Identity

| Field | Source | Notes |
|---|---|---|
| ``Identity/ICAOTypeDesignator`` | join key | Primary key for the composite. |
| ``Identity/IATACodes`` | APD | FAA does not publish IATA codes. Multiple `/`-separated codes are split. |
| ``Identity/manufacturer`` | FAA → APD | First FAA row, then APD fallback. |
| ``Identity/model`` | FAA → APD | First FAA row, then APD fallback. |
| ``Identity/alternativeNames`` | APD | Free-text variant nicknames published by EUROCONTROL. |
| ``Identity/aircraftClass`` | APD | Derived from the ICAO Doc 8643 description code. |
| ``Identity/engineCount`` | APD | Derived from the ICAO Doc 8643 description code. |
| ``Identity/engineType`` | APD | Derived from the ICAO Doc 8643 description code. |

### Categories

| Field | Source | Notes |
|---|---|---|
| ``Categories/approach`` | FAA → APD | FAA AAC; falls back to APD APC. |
| ``Categories/designGroup`` | FAA only | Airplane Design Group (I–VI). |
| ``Categories/taxiwayDesignGroup`` | FAA only | Taxiway Design Group (1A–7). |
| ``Categories/wakeTurbulence`` | APD only | ICAO WTC: L/M/H/J. |
| ``Categories/RECAT_EU`` | APD only | RECAT-EU: CAT-A through CAT-F. |

### Dimensions (all stored in feet)

| Field (Measurement) | Stored property | Source |
|---|---|---|
| ``Dimensions/wingspan`` | ``Dimensions/wingspanFt`` | FAA → APD |
| ``Dimensions/length`` | ``Dimensions/lengthFt`` | FAA → APD |
| ``Dimensions/tailHeight`` | ``Dimensions/tailHeightFt`` | FAA → APD |

### Weights

| Field (Measurement) | Stored property | Source |
|---|---|---|
| ``Weights/MTOW`` | ``Weights/MTOWLb`` | FAA → APD |
| ``Weights/mainGearWidth`` | ``Weights/mainGearWidthFt`` | FAA only |
| ``Weights/cockpitToMainGear`` | ``Weights/cockpitToMainGearFt`` | FAA only |

### Recognition (APD only)

| Field | Source |
|---|---|
| ``Recognition/wing`` | APD |
| ``Recognition/engine`` | APD |
| ``Recognition/tail`` | APD |
| ``Recognition/landingGear`` | APD |

### Performance (APD only)

Every nested phase is APD-only — the FAA ACD does not publish a flight
envelope.

| Phase | Field (Measurement) | Stored property |
|---|---|---|
| Takeoff | `Performance.Takeoff.v2` | `v2Kt` |
| Takeoff | `Performance.Takeoff.distance` | `distanceFt` |
| Climb (initial / FL150 / FL240) | `Performance.ClimbBand.IAS` | `IASKt` |
| Climb (initial / FL150 / FL240) | `Performance.ClimbBand.rateOfClimb` | `rateOfClimbFPM` |
| Climb | `Performance.Climb.machClimb` | dimensionless `Double` |
| Cruise | `Performance.Cruise.TAS` | `TASKt` |
| Cruise | `Performance.Cruise.mach` | dimensionless `Double` |
| Cruise | `Performance.Cruise.ceiling` | `ceilingFt` |
| Cruise | `Performance.Cruise.range` | `rangeNmi` |
| Descent (initial / descent) | `Performance.DescentBand.IAS` | `IASKt` |
| Descent (initial / descent) | `Performance.DescentBand.rateOfDescent` | `rateOfDescentFPM` |
| Approach | `Performance.Approach.minimumCleanSpeed` | `minimumCleanSpeedKt` |
| Approach | `Performance.Approach.rateOfDescent` | `rateOfDescentFPM` |
| Landing | `Performance.Landing.vat` | `vatKt` |
| Landing | `Performance.Landing.distance` | `distanceFt` |

### Variants (FAA only)

Each ``Variant`` is a verbatim projection of one FAA spreadsheet row.

| Field | Source |
|---|---|
| ``Variant/manufacturer`` | FAA |
| ``Variant/model`` | FAA |
| ``Variant/approachSpeed`` (`approachSpeedKt`) | FAA |
| ``Variant/dimensions`` | FAA |
| ``Variant/weights`` | FAA |
| ``Variant/categories`` | FAA |

## Measurement convention

Every physical quantity is stored as a raw `Double` in a fixed source unit and
exposed as a Foundation `Measurement<UnitX>` computed property. Use
`.converted(to:)` for unit conversions:

```swift
let span   = profile.dimensions?.wingspan.converted(to: .meters)
let MTOW   = profile.weights?.MTOW.converted(to: .kilograms)
let cruise = profile.performance?.cruise.TAS?.converted(to: .kilometersPerHour)
```

Mach values are dimensionless `Double`s — Foundation has no `UnitMach`.

## EUROCONTROL copyright notice

The EUROCONTROL APD landing page states that "Copyright permission must be
sought from EUROCONTROL." SwiftACD only enables programmatic access to the
data; it does **not** grant any redistribution rights. If you intend to
republish, redistribute, or otherwise reuse APD-derived content (including
within a shipped product or a public dataset), you are responsible for
obtaining permission directly from EUROCONTROL beforehand. The FAA ACD is
U.S. Government work and not subject to the same restriction.
