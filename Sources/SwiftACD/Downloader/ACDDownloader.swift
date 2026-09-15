import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import SwiftSoup

// Scrapes the FAA landing page, locates the most recent `.xlsx` link, and
// streams the file to disk.
struct ACDDownloader: Sendable {

  static let landingPage = URL(
    string: "https://www.faa.gov/airports/engineering/aircraft_char_database"
  )!

  let session: URLSession
  let userAgent: String

  init(
    session: URLSession = .shared,
    userAgent: String = defaultUserAgent
  ) {
    self.session = session
    self.userAgent = userAgent
  }

  // MARK: - Static helpers

  private static func firstXlsxLink(in document: Document, selector: String) throws -> URL? {
    let containers = try document.select(selector)
    for container in containers.array() {
      var explicit: URL?
      var heuristic: URL?
      for anchor in try container.select("a[href]").array() {
        let href = try anchor.attr("href")
        guard !href.isEmpty else { continue }
        if explicit == nil, hrefIsXlsx(href), let resolved = resolve(href: href) {
          explicit = resolved
          continue
        }
        if heuristic == nil {
          let text = try anchor.text().trimmingCharacters(in: .whitespacesAndNewlines)
          guard textLooksLikeWorkbookAnchor(text),
            let resolved = resolve(href: href),
            resolved.absoluteString != landingPage.absoluteString,
            !resolved.absoluteString.hasPrefix("mailto:")
          else { continue }
          heuristic = resolved
        }
      }
      if let url = explicit ?? heuristic { return url }
    }
    return nil
  }

  // Workbook anchor text starts with "Aircraft Characteristics" but is *not*
  // the navigation back-link "Aircraft Characteristics Database".
  private static func textLooksLikeWorkbookAnchor(_ text: String) -> Bool {
    let lower = text.lowercased()
    guard lower.hasPrefix("aircraft characteristics") else { return false }
    if lower.hasSuffix("database") { return false }
    return true
  }

  private static func hrefIsXlsx(_ href: String) -> Bool {
    if let path = URL(string: href, relativeTo: landingPage)?.path {
      return path.lowercased().hasSuffix(".xlsx")
    }
    return href.lowercased().hasSuffix(".xlsx")
  }

  private static func resolve(href: String) -> URL? {
    if let url = URL(string: href), url.scheme != nil {
      return url
    }
    return URL(string: href, relativeTo: landingPage)?.absoluteURL
  }

  private static func filename(for url: URL) -> String {
    let component = url.lastPathComponent
    let decoded = component.removingPercentEncoding ?? component
    // FAA serves the workbook from an extension-less URL; the rest of the
    // pipeline expects `*.xlsx`. Append the extension when it's absent.
    if decoded.lowercased().hasSuffix(".xlsx") || decoded.lowercased().hasSuffix(".xls") {
      return decoded
    }
    return "\(decoded).xlsx"
  }

  // MARK: - Instance methods

  func download(
    into directory: URL,
    progress: ProgressManager?
  ) async throws -> URL {
    let html = try await fetchLandingPage()
    let xlsxURL = try resolveXlsxURL(from: html)
    return try await downloadFile(
      from: xlsxURL,
      into: directory,
      progress: progress
    )
  }

  private func fetchLandingPage() async throws -> String {
    var request = URLRequest(url: Self.landingPage)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

    let (data, response) = try await session.data(for: request)
    try ensureHTTPSuccess(request: request, response: response)
    return String(data: data, encoding: .utf8) ?? ""
  }

  private func resolveXlsxURL(from html: String) throws -> URL {
    let document: Document
    do {
      document = try SwiftSoup.parse(html, Self.landingPage.absoluteString)
    } catch {
      throw SwiftACDError.ACDSpreadsheetLinkNotFound(pageURL: Self.landingPage)
    }

    // Try root containers in priority order.
    let containerSelectors = ["main", "article", "body"]
    for selector in containerSelectors {
      if let url = try Self.firstXlsxLink(in: document, selector: selector) {
        return url
      }
    }
    throw SwiftACDError.ACDSpreadsheetLinkNotFound(pageURL: Self.landingPage)
  }

  private func downloadFile(
    from url: URL,
    into directory: URL,
    progress: ProgressManager?
  ) async throws -> URL {
    var request = URLRequest(url: url)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    let filename = Self.filename(for: url)
    let fileURL = directory.appendingPathComponent(filename)

    #if canImport(FoundationNetworking)
      // swift-corelibs-foundation's URLSession has no byte-streaming API, so
      // the whole response is buffered before it's written to disk.
      let (data, response) = try await session.data(for: request)
      try ensureHTTPSuccess(request: request, response: response)
      try data.write(to: fileURL)
      // One indivisible unit: without a streaming API there is nothing to
      // report until the whole body has arrived.
      progress?.totalByteCount = UInt64(data.count)
      progress?.completedByteCount = UInt64(data.count)
      progress?.setTotalCount(1)
      progress?.setCompletedCount(1)
    #else
      let (bytes, response) = try await session.bytes(for: request)
      try ensureHTTPSuccess(request: request, response: response)

      // Create / truncate the destination file.
      FileManager.default.createFile(atPath: fileURL.path, contents: nil)
      let handle = try FileHandle(forWritingTo: fileURL)
      defer { try? handle.close() }

      let total = (response as? HTTPURLResponse)?.expectedContentLength ?? -1
      if total > 0 {
        progress?.setTotalCount(Int(total))
        progress?.totalByteCount = UInt64(total)
      }
      var written = 0
      var buffer = Data()
      buffer.reserveCapacity(64 * 1024)

      func flush(_ buffer: inout Data) throws {
        guard !buffer.isEmpty else { return }
        try handle.write(contentsOf: buffer)
        written += buffer.count
        buffer.removeAll(keepingCapacity: true)
        progress?.setCompletedCount(written)
        progress?.completedByteCount = UInt64(written)
      }

      for try await byte in bytes {
        buffer.append(byte)
        if buffer.count >= 64 * 1024 { try flush(&buffer) }
      }
      try flush(&buffer)
    #endif

    return fileURL
  }
}
