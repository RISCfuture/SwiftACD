import CoreXLSX
import Foundation

struct ACDParser {

  // CoreXLSX hasn't marked `ColumnReference` Sendable, but the value is
  // constructed once and only read thereafter.
  nonisolated(unsafe) private static let firstColumn = ColumnReference("A")!

  let url: URL

  private static func expandRow(_ row: Row, sharedStrings: SharedStrings?) -> [String] {
    let columnIndices = row.cells.map { firstColumn.distance(to: $0.reference.column) }
    let maxIndex = columnIndices.max() ?? -1
    var result = Array(repeating: "", count: maxIndex + 1)
    for (cell, idx) in zip(row.cells, columnIndices) {
      guard idx >= 0 else { continue }
      result[idx] =
        cell.value(in: sharedStrings)?.trimmingCharacters(in: .whitespacesAndNewlines)
        ?? ""
    }
    return result
  }

  private static func parseRow(
    _ cells: [String],
    columns: ACDColumns,
    rowNumber: Int
  ) throws -> ACDRow? {
    func get(_ idx: Int?) -> String? {
      guard let i = idx, i < cells.count else { return nil }
      let value = cells[i]
      if value.isEmpty { return nil }
      // Treat the FAA's "no value" sentinels as empty so they don't trip
      // strict enum decoding downstream.
      let normalized = value.lowercased()
      if normalized == "n/a" || normalized == "na" || normalized == "-" || normalized == "none" {
        return nil
      }
      return value
    }

    guard let ICAO = get(columns.ICAO) else { return nil }

    func parseEnum<E: RawRepresentable>(
      _ idx: Int?,
      _: E.Type,
      makeError: (String) -> SwiftACDError
    ) throws -> E? where E.RawValue == String {
      guard let raw = get(idx) else { return nil }
      if let value = E(rawValue: raw) { return value }
      // Be tolerant — some FAA cells embed extra whitespace or trailing
      // notes ("III(*)"). Strip non-alphanumeric tail and retry.
      let trimmed = raw.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
      if !trimmed.isEmpty, let value = E(rawValue: trimmed) { return value }
      throw makeError(raw)
    }

    let approachCategory = try parseEnum(
      columns.approachCategory,
      AircraftApproachCategory.self,
      makeError: { raw in
        .unknownAircraftApproachCategory(rawValue: raw, context: .ACDRow(rowNumber))
      }
    )
    let designGroup = try parseEnum(
      columns.designGroup,
      AirplaneDesignGroup.self,
      makeError: { raw in
        .unknownAirplaneDesignGroup(rawValue: raw, context: .ACDRow(rowNumber))
      }
    )
    let taxiwayDesignGroup = try parseEnum(
      columns.taxiwayDesignGroup,
      TaxiwayDesignGroup.self,
      makeError: { raw in
        .unknownTaxiwayDesignGroup(rawValue: raw, context: .ACDRow(rowNumber))
      }
    )

    return ACDRow(
      rowNumber: rowNumber,
      ICAOTypeDesignator: ICAO,
      manufacturer: get(columns.manufacturer),
      model: get(columns.model),
      approachCategory: approachCategory,
      designGroup: designGroup,
      taxiwayDesignGroup: taxiwayDesignGroup,
      MTOWLb: get(columns.MTOW).flatMap(ParsingHelpers.parseDouble),
      mainGearWidthFt: get(columns.mainGearWidth).flatMap(ParsingHelpers.parseDouble),
      cockpitToMainGearFt: get(columns.cockpitToMainGear).flatMap(ParsingHelpers.parseDouble),
      wingspanFt: get(columns.wingspan).flatMap(ParsingHelpers.parseDouble),
      lengthFt: get(columns.length).flatMap(ParsingHelpers.parseDouble),
      tailHeightFt: get(columns.tailHeight).flatMap(ParsingHelpers.parseDouble),
      approachSpeedKt: get(columns.approachSpeed).flatMap(ParsingHelpers.parseDouble)
    )
  }

  func parse(errorCallback: (Error) -> Void) throws -> [ACDRow] {
    guard let xlsx = XLSXFile(filepath: url.path) else {
      throw SwiftACDError.malformedWorkbook(url: url, reason: .couldNotOpenArchive)
    }

    let sharedStrings = try? xlsx.parseSharedStrings()

    let worksheetPaths = try xlsx.parseWorksheetPaths()
    guard let firstPath = worksheetPaths.first else {
      throw SwiftACDError.malformedWorkbook(url: url, reason: .noWorksheets)
    }

    // Pick the worksheet with the most non-empty rows — ACD workbooks have
    // ancillary sheets (cover page, units legend) we want to ignore.
    var bestSheet: (path: String, sheet: Worksheet, rowCount: Int) = (
      firstPath,
      try xlsx.parseWorksheet(at: firstPath),
      0
    )
    for path in worksheetPaths {
      let sheet = try xlsx.parseWorksheet(at: path)
      let count = sheet.data?.rows.count ?? 0
      if count > bestSheet.rowCount {
        bestSheet = (path, sheet, count)
      }
    }
    let worksheet = bestSheet.sheet
    let rows = worksheet.data?.rows ?? []
    guard !rows.isEmpty else {
      throw SwiftACDError.malformedWorkbook(url: url, reason: .worksheetEmpty)
    }

    // The first row containing more than one populated cell is the header.
    guard
      let headerIndex = rows.firstIndex(where: { row in
        row.cells.compactMap { $0.value(in: sharedStrings) }.count > 1
      })
    else {
      throw SwiftACDError.malformedWorkbook(url: url, reason: .noHeaderRow)
    }

    let headerRow = Self.expandRow(rows[headerIndex], sharedStrings: sharedStrings)
    let columns = try ACDColumns.resolve(headerRow: headerRow)

    var output: [ACDRow] = []
    output.reserveCapacity(rows.count - headerIndex)
    for (offset, row) in rows.enumerated() where offset > headerIndex {
      let cells = Self.expandRow(row, sharedStrings: sharedStrings)
      let rowNumber = Int(row.reference)
      do {
        guard let parsed = try Self.parseRow(cells, columns: columns, rowNumber: rowNumber) else {
          continue
        }
        output.append(parsed)
      } catch {
        errorCallback(error)
      }
    }
    return output
  }
}

extension Cell {
  // Hops through SharedStrings when applicable; falls back to the raw `value`
  // for inline / formula cells.
  fileprivate func value(in sharedStrings: SharedStrings?) -> String? {
    if let sharedStrings, let str = stringValue(sharedStrings) {
      return str
    }
    if let inlineString {
      return inlineString.text
    }
    return value
  }
}
