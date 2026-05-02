import Foundation
import SwiftSoup

// Walks the public list page (`default.aspx`), extracts every ICAO type
// designator, then fetches each `details.aspx?ICAO=…` page with bounded
// concurrency.
struct APDDownloader: Sendable {

  static let listPage = URL(
    string: "https://learningzone.eurocontrol.int/ilp/customs/ATCPFDB/default.aspx"
  )!

  // Caller appends `?ICAO=XXX`.
  static let detailBase = URL(
    string: "https://learningzone.eurocontrol.int/ilp/customs/ATCPFDB/details.aspx"
  )!

  private static let allowedFormCharacters: CharacterSet = {
    var set = CharacterSet.alphanumerics
    set.insert(charactersIn: "-._~")
    return set
  }()

  let session: URLSession
  let userAgent: String
  let maxConcurrent: Int
  let requestDelay: Duration

  init(
    session: URLSession = .shared,
    userAgent: String = defaultUserAgent,
    maxConcurrent: Int = 6,
    requestDelay: Duration = .milliseconds(50)
  ) {
    self.session = session
    self.userAgent = userAgent
    self.maxConcurrent = maxConcurrent
    self.requestDelay = requestDelay
  }

  // MARK: - Static helpers

  static func detailURL(for ICAO: String) -> URL {
    var components = URLComponents(url: detailBase, resolvingAgainstBaseURL: false)!
    components.queryItems = [URLQueryItem(name: "ICAO", value: ICAO)]
    return components.url!
  }

  // Pulls every `<input type="hidden">` (notably `__VIEWSTATE`,
  // `__VIEWSTATEGENERATOR`, `__EVENTVALIDATION`) so they can be replayed in
  // the next postback.
  static func parseFormFields(in document: Document) throws -> [String: String] {
    var fields: [String: String] = [:]
    for input in try document.select("input[type=hidden]").array() {
      let name = try input.attr("name")
      guard !name.isEmpty else { continue }
      fields[name] = try input.attr("value")
    }
    return fields
  }

  // Page numbers reachable from the current page's pager
  // (`<a href="javascript:__doPostBack('…','Page$N')">`).
  static func pagerTargets(in document: Document) throws -> Set<Int> {
    var targets = Set<Int>()
    for anchor in try document.select("a[href]").array() {
      let href = try anchor.attr("href")
      guard let suffix = href.components(separatedBy: "Page$").last else { continue }
      let digits = suffix.prefix(while: \.isNumber)
      if let n = Int(digits) { targets.insert(n) }
    }
    return targets
  }

  static func encodeForm(_ fields: [String: String]) -> Data {
    let pairs = fields.map { name, value -> String in
      let n = name.addingPercentEncoding(withAllowedCharacters: allowedFormCharacters) ?? name
      let v = value.addingPercentEncoding(withAllowedCharacters: allowedFormCharacters) ?? value
      return "\(n)=\(v)"
    }
    return Data(pairs.joined(separator: "&").utf8)
  }

  static func extractICAOs(from document: Document) throws -> [String] {
    let anchors = try document.select("a[href]")
    var seen = Set<String>()
    var ordered: [String] = []
    for anchor in anchors.array() {
      let href = try anchor.attr("href")
      guard let ICAO = ICAO(fromHref: href) else { continue }
      if seen.insert(ICAO).inserted {
        ordered.append(ICAO)
      }
    }
    return ordered
  }

  private static func ICAO(fromHref href: String) -> String? {
    // Match anything that points to details.aspx with an ICAO query.
    guard href.lowercased().contains("details.aspx") else { return nil }

    // Resolve to absolute, then read the query.
    let resolved: URL? = {
      if let direct = URL(string: href), direct.scheme != nil {
        return direct
      }
      return URL(string: href, relativeTo: listPage)?.absoluteURL
    }()
    guard let url = resolved,
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return nil }

    for item in components.queryItems ?? [] {
      if item.name.lowercased() == "icao",
        let value = item.value, !value.isEmpty
      {
        return value
      }
    }
    return nil
  }

  // MARK: - Instance methods

  // Per-ICAO failures route to `errorCallback` and are skipped. The list page
  // itself is required and propagates as a thrown error.
  func download(
    into directory: URL,
    progressCallback: ProgressCallback?,
    errorCallback: @escaping @Sendable (Error) -> Void
  ) async throws -> URL {
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )

    // 1. List page (page 1).
    let listHTML = try await fetchListPage(into: directory)

    // 2. Enumerate ICAOs across every paginated page. The list page is an
    //    ASP.NET WebForms grid that uses __doPostBack, so we replay each
    //    Page$N postback in sequence to harvest all designators.
    let ICAOs = try await enumerateAllICAOs(initialHTML: listHTML)
    let total = Int64(ICAOs.count)
    let counter = Counter()

    // 3. Fetch each detail page with bounded concurrency + delay between
    //    request *starts*.
    try await withThrowingTaskGroup(of: Void.self) { group in
      var inFlight = 0
      var iterator = ICAOs.makeIterator()
      let limit = max(1, maxConcurrent)

      while let ICAO = iterator.next() {
        if inFlight >= limit {
          // Wait for one task to finish before scheduling the next.
          _ = try await group.next()
          inFlight -= 1
        }

        // Apply delay between request *starts*.
        if requestDelay > .zero {
          try await Task.sleep(for: requestDelay)
        }

        group.addTask {
          do {
            try await self.fetchDetailPage(ICAO: ICAO, into: directory)
          } catch {
            errorCallback(error)
          }
          let completed = await counter.increment()
          progressCallback?(.init(completed, of: total))
        }
        inFlight += 1
      }

      // Drain the rest.
      try await group.waitForAll()
    }

    return directory
  }

  private func fetchListPage(into directory: URL) async throws -> String {
    var request = URLRequest(url: Self.listPage)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

    let (data, response) = try await session.data(for: request)
    try ensureHTTPSuccess(request: request, response: response)

    let url = directory.appendingPathComponent("listpage.html")
    try data.write(to: url)
    return String(data: data, encoding: .utf8) ?? ""
  }

  private func fetchDetailPage(ICAO: String, into directory: URL) async throws {
    let url = Self.detailURL(for: ICAO)
    var request = URLRequest(url: url)
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

    let (data, response) = try await session.data(for: request)
    try ensureHTTPSuccess(request: request, response: response)

    let fileURL = directory.appendingPathComponent("\(ICAO).html")
    try data.write(to: fileURL)
  }

  // Walks every page of the ASP.NET-paginated grid by replaying its
  // `__doPostBack` events. Stops when a postback returns no new ICAOs or the
  // pager exposes no further `Page$N` link beyond the current one.
  private func enumerateAllICAOs(initialHTML: String) async throws -> [String] {
    var seen = Set<String>()
    var ordered: [String] = []
    var currentHTML = initialHTML
    var currentPage = 1
    let gridControl = "ctl00$MainContent$wsBasicSearchGridView"
    // Hard cap to defend against runaway pagination loops.
    let maxPages = 500

    while currentPage <= maxPages {
      let document: Document
      do {
        document = try SwiftSoup.parse(currentHTML, Self.listPage.absoluteString)
      } catch {
        break
      }

      let pageICAOs = try Self.extractICAOs(from: document)
      var addedAny = false
      for ICAO in pageICAOs where seen.insert(ICAO).inserted {
        ordered.append(ICAO)
        addedAny = true
      }
      if currentPage > 1, !addedAny {
        break
      }

      let pagerTargets = try Self.pagerTargets(in: document)
      let next = currentPage + 1
      guard pagerTargets.contains(next) else { break }

      let formFields = try Self.parseFormFields(in: document)
      currentHTML = try await postPagerEvent(
        target: gridControl,
        argument: "Page$\(next)",
        formFields: formFields
      )
      currentPage = next
    }

    return ordered
  }

  // POSTs a `__doPostBack`-equivalent form to the list page and returns the
  // rendered HTML.
  private func postPagerEvent(
    target: String,
    argument: String,
    formFields: [String: String]
  ) async throws -> String {
    var body = formFields
    body["__EVENTTARGET"] = target
    body["__EVENTARGUMENT"] = argument

    var request = URLRequest(url: Self.listPage)
    request.httpMethod = "POST"
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue(
      "application/x-www-form-urlencoded; charset=utf-8",
      forHTTPHeaderField: "Content-Type"
    )
    request.setValue(Self.listPage.absoluteString, forHTTPHeaderField: "Referer")
    request.httpBody = Self.encodeForm(body)

    let (data, response) = try await session.data(for: request)
    try ensureHTTPSuccess(request: request, response: response)
    return String(data: data, encoding: .utf8) ?? ""
  }
}

private actor Counter {
  private var value: Int64 = 0

  func increment() -> Int64 {
    value += 1
    return value
  }
}
