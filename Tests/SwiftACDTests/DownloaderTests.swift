import Foundation
import Testing

@testable import SwiftACD

// MARK: - URLProtocol mock

/// Thread-safe state shared by ``MockURLProtocol`` instances. Tests register
/// per-URL handlers and (optionally) a hook that observes simultaneous-request
/// counts.
private final class MockState: @unchecked Sendable {
  private let lock = NSLock()
  private var handlers: [String: @Sendable (URLRequest) -> MockResponse] = [:]
  private var inFlight = 0
  private(set) var maxInFlight = 0
  private(set) var startedURLs: [String] = []

  func register(
    _ url: URL,
    handler: @escaping @Sendable (URLRequest) -> MockResponse
  ) {
    lock.lock()
    defer { lock.unlock() }
    handlers[url.absoluteString] = handler
  }

  func handler(for url: URL) -> (@Sendable (URLRequest) -> MockResponse)? {
    lock.lock()
    defer { lock.unlock() }
    if let exact = handlers[url.absoluteString] { return exact }
    // Fall back to query-stripped match so APD detail URLs with
    // canonicalised query string ordering still resolve.
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    components?.fragment = nil
    if let normalized = components?.url?.absoluteString,
      let match = handlers[normalized]
    {
      return match
    }
    return nil
  }

  func enter(url: URL) {
    lock.lock()
    inFlight += 1
    if inFlight > maxInFlight { maxInFlight = inFlight }
    startedURLs.append(url.absoluteString)
    lock.unlock()
  }

  func leave() {
    lock.lock()
    inFlight -= 1
    lock.unlock()
  }
}

private struct MockResponse: Sendable {
  let statusCode: Int
  let headers: [String: String]
  let body: Data
  /// Optional per-byte delay used by the bounded-concurrency test to keep
  /// requests "in flight" long enough to overlap.
  let delay: Duration?

  init(
    statusCode: Int = 200,
    headers: [String: String] = ["Content-Type": "text/html; charset=utf-8"],
    body: Data,
    delay: Duration? = nil
  ) {
    self.statusCode = statusCode
    self.headers = headers
    self.body = body
    self.delay = delay
  }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
  /// `nonisolated(unsafe)` is acceptable here: the underlying `MockState`
  /// uses an internal lock and tests scope their own state per session.
  nonisolated(unsafe) static var current = MockState()

  // swiftlint:disable non_overridable_class_declaration static_over_final_class
  override class func canInit(with _: URLRequest) -> Bool { true }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }
  // swiftlint:enable non_overridable_class_declaration static_over_final_class

  override func startLoading() {
    let state = Self.current
    guard let url = request.url else {
      client?.urlProtocol(
        self,
        didFailWithError: URLError(.badURL)
      )
      return
    }
    guard let handler = state.handler(for: url) else {
      client?.urlProtocol(
        self,
        didFailWithError: URLError(.fileDoesNotExist)
      )
      return
    }
    state.enter(url: url)
    let response = handler(request)
    let httpResponse = HTTPURLResponse(
      url: url,
      statusCode: response.statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: response.headers
    )!

    let work: @Sendable () -> Void = { [weak self] in
      guard let self else { return }
      self.client?.urlProtocol(
        self,
        didReceive: httpResponse,
        cacheStoragePolicy: .notAllowed
      )
      self.client?.urlProtocol(self, didLoad: response.body)
      self.client?.urlProtocolDidFinishLoading(self)
      state.leave()
    }

    if let delay = response.delay {
      Task {
        try? await Task.sleep(for: delay)
        work()
      }
    } else {
      work()
    }
  }

  override func stopLoading() {}
}

private func makeSession() -> URLSession {
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [MockURLProtocol.self]
  return URLSession(configuration: configuration)
}

// MARK: - Test fixtures

private func tempDirectory() -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    "SwiftACDDownloaderTests-\(UUID().uuidString)"
  )
  try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

private let acdHTMLWithLink = """
  <html>
    <head><title>FAA</title></head>
    <body>
      <header><a href="/about">About</a></header>
      <main>
        <article>
          <p>Download the latest aircraft characteristics database:</p>
          <a href="/path/to/some.xlsx">Download</a>
        </article>
      </main>
    </body>
  </html>
  """

private let acdHTMLNoLink = """
  <html><body><main><a href="/index.html">Home</a></main></body></html>
  """

private let apdListHTML = """
  <html>
    <body>
      <table>
        <tr><td><a href="details.aspx?ICAO=A320">A320</a></td></tr>
        <tr><td><a href="details.aspx?ICAO=B738">B738</a></td></tr>
        <tr><td><a href="details.aspx?ICAO=C172">C172</a></td></tr>
      </table>
    </body>
  </html>
  """

// MARK: - Top-level grouping

/// All downloader tests share the global `MockURLProtocol` state, so they run
/// serialized.
@Suite("Downloader", .serialized)
struct DownloaderTests {}

// MARK: - ACDDownloader

extension DownloaderTests {

  @Suite("ACDDownloader", .serialized)
  struct ACDDownloaderTests {

    @Test("Resolves the .xlsx link and writes the file")
    func resolvesAndDownloads() async throws {
      MockURLProtocol.current = MockState()
      let session = makeSession()
      let directory = tempDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      let xlsxBody = Data((0..<1024).map { UInt8($0 & 0xff) })

      MockURLProtocol.current.register(ACDDownloader.landingPage) { _ in
        MockResponse(body: Data(acdHTMLWithLink.utf8))
      }
      let xlsxURL = URL(string: "https://www.faa.gov/path/to/some.xlsx")!
      MockURLProtocol.current.register(xlsxURL) { _ in
        MockResponse(
          headers: [
            "Content-Type":
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "Content-Length": "\(xlsxBody.count)"
          ],
          body: xlsxBody
        )
      }

      let downloader = ACDDownloader(session: session)
      let url = try await downloader.download(into: directory, progressCallback: nil)

      #expect(url.lastPathComponent == "some.xlsx")
      let written = try Data(contentsOf: url)
      #expect(written == xlsxBody)
    }

    @Test("Resolves the FAA-style extension-less link by anchor text")
    func resolvesExtensionLessLink() async throws {
      MockURLProtocol.current = MockState()
      let session = makeSession()
      let directory = tempDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      let resources = try #require(Bundle.module.resourceURL).appendingPathComponent(
        "TestResources"
      )
      let landingHTML = try Data(contentsOf: resources.appendingPathComponent("faa_landing.html"))
      let xlsxBody = Data((0..<2048).map { UInt8($0 & 0xff) })

      MockURLProtocol.current.register(ACDDownloader.landingPage) { _ in
        MockResponse(body: landingHTML)
      }
      let dataURL = URL(
        string: "https://www.faa.gov/airports/engineering/aircraft_char_database/aircraft_data"
      )!
      MockURLProtocol.current.register(dataURL) { _ in
        MockResponse(
          headers: [
            "Content-Type":
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "Content-Length": "\(xlsxBody.count)"
          ],
          body: xlsxBody
        )
      }

      let downloader = ACDDownloader(session: session)
      let url = try await downloader.download(into: directory, progressCallback: nil)

      // Extension-less URLs get `.xlsx` appended so the rest of the pipeline
      // (Parser.findACDWorkbook) finds the file.
      #expect(url.lastPathComponent == "aircraft_data.xlsx")
      let written = try Data(contentsOf: url)
      #expect(written == xlsxBody)
    }

    @Test("Throws when no .xlsx link is found on the landing page")
    func noLinkFound() async throws {
      MockURLProtocol.current = MockState()
      let session = makeSession()
      let directory = tempDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      MockURLProtocol.current.register(ACDDownloader.landingPage) { _ in
        MockResponse(body: Data(acdHTMLNoLink.utf8))
      }

      let downloader = ACDDownloader(session: session)
      do {
        _ = try await downloader.download(into: directory, progressCallback: nil)
        Issue.record("expected ACDSpreadsheetLinkNotFound")
      } catch let error as SwiftACDError {
        guard case .ACDSpreadsheetLinkNotFound = error else {
          Issue.record("wrong error \(error)")
          return
        }
      }
    }

    @Test("Throws .networkError when the landing page returns 500")
    func landingPage500() async throws {
      MockURLProtocol.current = MockState()
      let session = makeSession()
      let directory = tempDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      MockURLProtocol.current.register(ACDDownloader.landingPage) { _ in
        MockResponse(statusCode: 500, body: Data("server error".utf8))
      }

      let downloader = ACDDownloader(session: session)
      do {
        _ = try await downloader.download(into: directory, progressCallback: nil)
        Issue.record("expected networkError")
      } catch let error as SwiftACDError {
        guard case .networkError = error else {
          Issue.record("wrong error \(error)")
          return
        }
      }
    }
  }
}  // end DownloaderTests.ACDDownloaderTests extension

// MARK: - APDDownloader

extension DownloaderTests {

  @Suite("APDDownloader", .serialized)
  struct APDDownloaderTests {

    private static func registerListPage() {
      MockURLProtocol.current.register(APDDownloader.listPage) { _ in
        MockResponse(body: Data(apdListHTML.utf8))
      }
    }

    private static func detailURL(_ ICAO: String) -> URL {
      APDDownloader.detailURL(for: ICAO)
    }

    @Test("Enumerates ICAOs and downloads each detail page")
    func enumeratesAndDownloads() async throws {
      MockURLProtocol.current = MockState()
      let session = makeSession()
      let directory = tempDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      Self.registerListPage()
      for ICAO in ["A320", "B738", "C172"] {
        let url = Self.detailURL(ICAO)
        MockURLProtocol.current.register(url) { _ in
          MockResponse(body: Data("<html><body>\(ICAO)</body></html>".utf8))
        }
      }

      let downloader = APDDownloader(
        session: session,
        maxConcurrent: 3,
        requestDelay: .zero
      )
      let result = try await downloader.download(
        into: directory,
        progressCallback: nil,
        errorCallback: { _ in }
      )

      #expect(result == directory)

      let listFile = directory.appendingPathComponent("listpage.html")
      #expect(FileManager.default.fileExists(atPath: listFile.path))

      for ICAO in ["A320", "B738", "C172"] {
        let file = directory.appendingPathComponent("\(ICAO).html")
        #expect(FileManager.default.fileExists(atPath: file.path), "missing \(ICAO).html")
        let body = try String(contentsOf: file, encoding: .utf8)
        #expect(body.contains(ICAO))
      }
    }

    @Test("Skips a failing detail page and routes the error to the callback")
    func continuesOnFailure() async throws {
      MockURLProtocol.current = MockState()
      let session = makeSession()
      let directory = tempDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      Self.registerListPage()
      MockURLProtocol.current.register(Self.detailURL("A320")) { _ in
        MockResponse(body: Data("<html>A320</html>".utf8))
      }
      MockURLProtocol.current.register(Self.detailURL("B738")) { _ in
        MockResponse(statusCode: 500, body: Data("nope".utf8))
      }
      MockURLProtocol.current.register(Self.detailURL("C172")) { _ in
        MockResponse(body: Data("<html>C172</html>".utf8))
      }

      let errors = ErrorBox()
      let downloader = APDDownloader(
        session: session,
        maxConcurrent: 3,
        requestDelay: .zero
      )

      _ = try await downloader.download(
        into: directory,
        progressCallback: nil,
        errorCallback: { error in errors.append(error) }
      )

      #expect(
        FileManager.default.fileExists(
          atPath: directory.appendingPathComponent("A320.html").path
        )
      )
      #expect(
        !FileManager.default.fileExists(
          atPath: directory.appendingPathComponent("B738.html").path
        )
      )
      #expect(
        FileManager.default.fileExists(
          atPath: directory.appendingPathComponent("C172.html").path
        )
      )
      #expect(errors.count == 1)
    }

    @Test("Respects bounded concurrency", .timeLimit(.minutes(1)))
    func boundedConcurrency() async throws {
      MockURLProtocol.current = MockState()
      let session = makeSession()
      let directory = tempDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }

      Self.registerListPage()
      let perRequestDelay = Duration.milliseconds(120)
      for ICAO in ["A320", "B738", "C172"] {
        MockURLProtocol.current.register(Self.detailURL(ICAO)) { _ in
          MockResponse(
            body: Data("<html>\(ICAO)</html>".utf8),
            delay: perRequestDelay
          )
        }
      }

      let downloader = APDDownloader(
        session: session,
        maxConcurrent: 2,
        requestDelay: .zero
      )

      _ = try await downloader.download(
        into: directory,
        progressCallback: nil,
        errorCallback: { _ in }
      )

      #expect(
        MockURLProtocol.current.maxInFlight <= 2,
        "saw \(MockURLProtocol.current.maxInFlight) simultaneous requests"
      )
      #expect(MockURLProtocol.current.maxInFlight >= 1)
    }
  }
}  // end DownloaderTests.APDDownloaderTests extension

// MARK: - Test helpers

/// Thread-safe error accumulator for tests.
private final class ErrorBox: @unchecked Sendable {
  private let lock = NSLock()
  private var errors: [Error] = []

  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return errors.count
  }

  func append(_ error: Error) {
    lock.lock()
    errors.append(error)
    lock.unlock()
  }
}
