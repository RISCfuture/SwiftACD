import Foundation
import SwiftSoup

// APD HTML is generated from a fixed ASP.NET WebForms layout: identity /
// dimensions / recognition cells are `<span id="MainContent_ws…">`; every
// numeric performance value carries a stable `datagraph="…"` attribute.
enum APDExtractors {
  // MARK: - Labelled identity / dimensions / recognition spans

  // SwiftSoup errors are swallowed — a missing element is indistinguishable
  // from an empty one for this parser's purposes.
  static func text(_ document: Document, id: String) -> String? {
    guard let element = try? document.getElementById(id) else { return nil }
    let raw = (try? element.text()) ?? ""
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  // Like `text(_:id:)` but treats EUROCONTROL placeholder strings as absent.
  static func meaningfulText(_ document: Document, id: String) -> String? {
    guard let raw = text(document, id: id) else { return nil }
    if Self.isPlaceholder(raw) { return nil }
    return raw
  }

  // List is empirically derived from spot-checks across the live APD.
  static func isPlaceholder(_ string: String) -> Bool {
    let lowered = string.lowercased()
    return lowered.isEmpty
      || lowered == "no"
      || lowered == "no data"
      || lowered == "-"
      || lowered == "n/a"
      || lowered == "na"
  }

  // MARK: - List-of-strings cells

  static func splitSlashSeparated(_ document: Document, id: String) -> [String] {
    guard let raw = meaningfulText(document, id: id) else { return [] }
    return
      raw
      .split(separator: "/", omittingEmptySubsequences: true)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  // EUROCONTROL emits these as a `<ul class='ap-detail-list'>` of
  // `<li><p>name</p></li>`; a missing list falls back to a single bare string.
  static func alternativeNames(_ document: Document) -> [String] {
    guard let element = try? document.getElementById("MainContent_wsLabelAlternativeNames")
    else { return [] }
    let listItems = (try? element.select("li").array()) ?? []
    if !listItems.isEmpty {
      var out: [String] = []
      out.reserveCapacity(listItems.count)
      for item in listItems {
        let raw = (try? item.text()) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { out.append(trimmed) }
      }
      return out
    }
    let raw = (try? element.text()) ?? ""
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || isPlaceholder(trimmed) { return [] }
    return [trimmed]
  }

  // MARK: - Performance phase values

  // Page layout:
  //   <span class="ap-list-item-perf-value" datagraph="key">VALUE</span>
  //   <span class="ap-list-item-perf-unit">UNIT</span>
  // The unit span is optional (some Mach values omit it).
  static func perfValue(_ document: Document, datagraph: String) -> (
    value: String, unit: String?
  )? {
    guard
      let valueElement = try? document.select("span[datagraph=\(datagraph)]").first()
    else { return nil }
    let rawValue = (try? valueElement.text()) ?? ""
    let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedValue.isEmpty { return nil }
    let unit: String? = {
      guard let next = try? valueElement.nextElementSibling() else { return nil }
      let className = (try? next.className()) ?? ""
      guard className.contains("ap-list-item-perf-unit") else { return nil }
      let raw = (try? next.text()) ?? ""
      let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }()
    return (trimmedValue, unit)
  }

  static func perfDouble(_ document: Document, datagraph: String) -> Double? {
    guard let pair = perfValue(document, datagraph: datagraph) else { return nil }
    return parseDouble(pair.value)
  }

  // MARK: - Numeric helpers

  static func parseDouble(_ string: String) -> Double? {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || isPlaceholder(trimmed) { return nil }
    return ParsingHelpers.parseDouble(trimmed)
  }
}
