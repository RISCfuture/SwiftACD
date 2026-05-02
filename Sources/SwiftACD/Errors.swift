import Foundation

/// Errors thrown by SwiftACD's downloaders, parsers, and builder.
///
/// Per-record errors are surfaced through the `errorCallback` parameter on
/// ``Parser/parse(progress:errorCallback:)`` and the parser continues; only
/// fatal errors (network failures, missing files) propagate via `throws`.
public enum SwiftACDError: Swift.Error, Sendable {

  // MARK: Download errors

  /// The FAA landing page returned a successful response but contained no
  /// `.xlsx` link.
  case ACDSpreadsheetLinkNotFound(pageURL: URL)

  /// HTTP-level failure while downloading.
  case networkError(request: URLRequest, response: URLResponse?)

  /// A file expected on disk was not found.
  case fileNotFound(url: URL)

  // MARK: Parse errors

  /// The FAA workbook is structurally invalid (missing sheet, no header row,
  /// unreadable shared strings).
  case malformedWorkbook(url: URL, reason: MalformedWorkbookReason)

  /// The FAA header row did not contain a recognized column for the named
  /// field. `field` is the canonical column identifier (e.g. `"ICAO Type
  /// Designator"`); it is not localized.
  case missingACDColumn(field: String)

  /// A required cell on a FAA row was empty or unparseable. `field` is the
  /// canonical column identifier; it is not localized.
  case invalidACDCell(field: String, value: String, row: Int)

  /// An EUROCONTROL detail page could not be parsed (HTML missing the
  /// expected structure).
  case malformedAPDPage(ICAO: String, reason: MalformedAPDPageReason)

  // MARK: Domain enum decode failures

  case unknownAircraftApproachCategory(rawValue: String, context: SwiftACDErrorContext)
  case unknownAirplaneDesignGroup(rawValue: String, context: SwiftACDErrorContext)
  case unknownTaxiwayDesignGroup(rawValue: String, context: SwiftACDErrorContext)
  case unknownWakeTurbulenceCategory(rawValue: String, context: SwiftACDErrorContext)
  case unknownRECATEU(rawValue: String, context: SwiftACDErrorContext)
  case unknownAircraftClass(rawValue: String, context: SwiftACDErrorContext)
  case unknownEngineType(rawValue: String, context: SwiftACDErrorContext)
  case unknownEngineCount(rawValue: String, context: SwiftACDErrorContext)
}

/// Structural failure modes for a FAA ACD workbook.
public enum MalformedWorkbookReason: Sendable, Equatable {
  case couldNotOpenArchive
  case noWorksheets
  case worksheetEmpty
  case noHeaderRow
}

extension MalformedWorkbookReason {
  /// A human-readable, localized description of this workbook failure.
  public var localizedDescription: String {
    switch self {
      case .couldNotOpenArchive:
        return String(
          localized: "could not open archive",
          bundle: .module,
          comment: "malformed workbook reason"
        )
      case .noWorksheets:
        return String(
          localized: "workbook has no worksheets",
          bundle: .module,
          comment: "malformed workbook reason"
        )
      case .worksheetEmpty:
        return String(
          localized: "primary worksheet is empty",
          bundle: .module,
          comment: "malformed workbook reason"
        )
      case .noHeaderRow:
        return String(
          localized: "no header row found",
          bundle: .module,
          comment: "malformed workbook reason"
        )
    }
  }
}

/// Failure modes for a EUROCONTROL APD detail page. The associated `underlying`
/// string is the localized description from the failing library call (file I/O
/// or `SwiftSoup`) and is passed through verbatim.
public enum MalformedAPDPageReason: Sendable, Equatable {
  case fileReadFailed(underlying: String)
  case htmlParseFailed(underlying: String)
}

extension MalformedAPDPageReason {
  /// A human-readable, localized description of this APD page failure,
  /// including the underlying error from the failing library call.
  public var localizedDescription: String {
    switch self {
      case let .fileReadFailed(underlying):
        return String(
          localized: "could not read file: \(underlying)",
          bundle: .module,
          comment: "malformed APD page reason"
        )
      case let .htmlParseFailed(underlying):
        return String(
          localized: "HTML parse failed: \(underlying)",
          bundle: .module,
          comment: "malformed APD page reason"
        )
    }
  }
}

/// Where in the input data a parse error originated. Currently only ACD rows
/// carry a positional context; APD records identify themselves via the
/// `malformedAPDPage` error's `ICAO` field.
public enum SwiftACDErrorContext: Sendable, Equatable {
  case ACDRow(Int)
}

extension SwiftACDErrorContext {
  /// A human-readable, localized description of where in the input data the
  /// error originated (e.g., the row number on an ACD spreadsheet).
  public var localizedDescription: String {
    switch self {
      case let .ACDRow(row):
        return String(
          localized: "ACD row \(row, format: .number)",
          bundle: .module,
          comment: "error context for an ACD row number"
        )
    }
  }
}

extension SwiftACDError: LocalizedError {
  public var errorDescription: String? {
    switch self {
      case .ACDSpreadsheetLinkNotFound, .networkError, .fileNotFound:
        return String(
          localized: "Failed to download aircraft database.",
          bundle: .module,
          comment: "error description"
        )
      default:
        return String(
          localized: "Failed to parse aircraft database.",
          bundle: .module,
          comment: "error description"
        )
    }
  }

  public var failureReason: String? {
    switch self {
      case let .ACDSpreadsheetLinkNotFound(pageURL):
        return String(
          localized: "No .xlsx link was found on the FAA ACD page \(pageURL.absoluteString).",
          bundle: .module,
          comment: "failure reason"
        )
      case let .networkError(request, response):
        let url = request.url?.absoluteString
        if let http = response as? HTTPURLResponse {
          if let url {
            return String(
              localized:
                "HTTP response \(http.statusCode) received when downloading from \(url).",
              bundle: .module,
              comment: "failure reason"
            )
          }
          return String(
            localized: "HTTP response \(http.statusCode) received from an unknown URL.",
            bundle: .module,
            comment: "failure reason"
          )
        }
        if let url {
          return String(
            localized: "Unexpected network error occurred when downloading from \(url).",
            bundle: .module,
            comment: "failure reason"
          )
        }
        return String(
          localized: "Unexpected network error occurred when downloading from an unknown URL.",
          bundle: .module,
          comment: "failure reason"
        )
      case let .fileNotFound(url):
        return String(
          localized: "File not found: \(url.path()).",
          bundle: .module,
          comment: "failure reason"
        )
      case let .malformedWorkbook(url, reason):
        return String(
          localized:
            "FAA workbook \(url.lastPathComponent) is malformed: \(reason.localizedDescription).",
          bundle: .module,
          comment: "failure reason"
        )
      case let .missingACDColumn(field):
        return String(
          localized: "FAA workbook header row has no column for \(field).",
          bundle: .module,
          comment: "failure reason"
        )
      case let .invalidACDCell(field, value, row):
        return String(
          localized: "FAA row \(row, format: .number) has an invalid \(field) value \(value).",
          bundle: .module,
          comment: "failure reason"
        )
      case let .malformedAPDPage(ICAO, reason):
        return String(
          localized:
            "EUROCONTROL detail page for \(ICAO) is malformed: \(reason.localizedDescription).",
          bundle: .module,
          comment: "failure reason"
        )

      case let .unknownAircraftApproachCategory(rawValue, context):
        return String(
          localized:
            "Unknown Aircraft Approach Category value \(rawValue) (\(context.localizedDescription)).",
          bundle: .module,
          comment: "failure reason for unknown enum raw value"
        )
      case let .unknownAirplaneDesignGroup(rawValue, context):
        return String(
          localized:
            "Unknown Airplane Design Group value \(rawValue) (\(context.localizedDescription)).",
          bundle: .module,
          comment: "failure reason for unknown enum raw value"
        )
      case let .unknownTaxiwayDesignGroup(rawValue, context):
        return String(
          localized:
            "Unknown Taxiway Design Group value \(rawValue) (\(context.localizedDescription)).",
          bundle: .module,
          comment: "failure reason for unknown enum raw value"
        )
      case let .unknownWakeTurbulenceCategory(rawValue, context):
        return String(
          localized:
            "Unknown Wake Turbulence Category value \(rawValue) (\(context.localizedDescription)).",
          bundle: .module,
          comment: "failure reason for unknown enum raw value"
        )
      case let .unknownRECATEU(rawValue, context):
        return String(
          localized:
            "Unknown RECAT-EU value \(rawValue) (\(context.localizedDescription)).",
          bundle: .module,
          comment: "failure reason for unknown enum raw value"
        )
      case let .unknownAircraftClass(rawValue, context):
        return String(
          localized:
            "Unknown Aircraft Class value \(rawValue) (\(context.localizedDescription)).",
          bundle: .module,
          comment: "failure reason for unknown enum raw value"
        )
      case let .unknownEngineType(rawValue, context):
        return String(
          localized:
            "Unknown Engine Type value \(rawValue) (\(context.localizedDescription)).",
          bundle: .module,
          comment: "failure reason for unknown enum raw value"
        )
      case let .unknownEngineCount(rawValue, context):
        return String(
          localized:
            "Unknown Engine Count value \(rawValue) (\(context.localizedDescription)).",
          bundle: .module,
          comment: "failure reason for unknown enum raw value"
        )
    }
  }

  public var recoverySuggestion: String? {
    switch self {
      case let .networkError(request, _):
        if let url = request.url?.absoluteString {
          return String(
            localized: "Verify that \(url) is reachable.",
            bundle: .module,
            comment: "recovery suggestion"
          )
        }
        return String(
          localized: "Verify that the source URL is reachable.",
          bundle: .module,
          comment: "recovery suggestion"
        )
      case .fileNotFound:
        return String(
          localized: "Verify the file was not moved or deleted.",
          bundle: .module,
          comment: "recovery suggestion"
        )
      case .ACDSpreadsheetLinkNotFound:
        return String(
          localized: "Verify the FAA ACD page URL has not changed.",
          bundle: .module,
          comment: "recovery suggestion"
        )
      default:
        return nil
    }
  }
}
