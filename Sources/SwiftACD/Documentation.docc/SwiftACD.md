# ``SwiftACD``

A composite aircraft-type profile library combining the FAA Aircraft
Characteristics Database with the EUROCONTROL Aircraft Performance Database.

## Overview

SwiftACD downloads, parses, and folds two complementary public datasets — the
**FAA Aircraft Characteristics Database (ACD)** and the **EUROCONTROL Aircraft
Performance Database (APD)** — into a single dictionary of
``AircraftProfile`` values keyed by ICAO type designator. The FAA ACD owns
airport-design fields (approach category, design groups, MTOW, gear geometry);
EUROCONTROL APD owns identity metadata, RECAT-EU/WTC classifications, and the
full takeoff through landing performance envelope. Top-level fields follow a
**prefer-FAA, fall back to APD** rule for any quantity both sources publish;
every original FAA row is also preserved on ``AircraftProfile/variants`` so
callers can address individual configurations such as winglets vs. no
winglets.

Every physical quantity is stored as a raw scalar in a fixed source unit
(feet, pounds, knots, feet-per-minute, nautical miles) and exposed as a
Foundation `Measurement<UnitX>` computed property. Use `.converted(to:)` to
get the unit you need.

## Topics

### Entry Points

- ``Parser``
- ``Downloader``
- ``AsyncProgress``
- ``Progress``
- ``ProgressCallback``

### Composite Models

- ``AircraftProfile``
- ``Identity``
- ``Categories``
- ``Dimensions``
- ``Weights``
- ``Recognition``
- ``Performance``
- ``Variant``
- ``Source``

### Domain Enums

- ``AircraftApproachCategory``
- ``AirplaneDesignGroup``
- ``TaxiwayDesignGroup``
- ``WakeTurbulenceCategory``
- ``RECATEU``
- ``AircraftClass``
- ``EngineType``
- ``EngineCount``
- ``WingPosition``
- ``EnginePosition``
- ``TailConfiguration``
- ``LandingGearConfiguration``

### Errors

- ``SwiftACDError``

### Articles

- <doc:Sources>
