import Foundation

/// Public facade for downloading the FAA ACD workbook and the EUROCONTROL
/// APD detail pages into a working directory.
///
/// Pass the resulting working directory to ``Parser`` to parse the data into
/// composite ``AircraftProfile`` records.
///
/// ```swift
/// let downloader = try Downloader()
/// let directory = try await downloader.downloadAll()
/// ```
public struct Downloader: Sendable {

  /// The directory all artifacts are written into.
  public let workingDirectory: URL

  private let progressCallback: ProgressCallback?
  private let acdDownloader: ACDDownloader
  private let apdDownloader: APDDownloader

  /// Creates a downloader.
  ///
  /// - Parameters:
  ///   - workingDirectory: Destination for the ACD workbook (root) and the
  ///     APD pages (`apd/` subdirectory). When `nil`, a unique temporary
  ///     directory is used.
  ///   - progressCallback: Receives progress updates for both downloads.
  public init(
    workingDirectory: URL? = nil,
    progressCallback: ProgressCallback? = nil
  ) throws {
    let directory =
      workingDirectory
      ?? FileManager.default.temporaryDirectory.appendingPathComponent(
        "SwiftACD-\(UUID().uuidString)"
      )
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    self.workingDirectory = directory
    self.progressCallback = progressCallback
    self.acdDownloader = ACDDownloader()
    self.apdDownloader = APDDownloader()
  }

  init(
    workingDirectory: URL,
    progressCallback: ProgressCallback? = nil,
    acdDownloader: ACDDownloader,
    apdDownloader: APDDownloader
  ) throws {
    try FileManager.default.createDirectory(
      at: workingDirectory,
      withIntermediateDirectories: true
    )
    self.workingDirectory = workingDirectory
    self.progressCallback = progressCallback
    self.acdDownloader = acdDownloader
    self.apdDownloader = apdDownloader
  }

  /// Downloads the FAA ACD workbook to the working-directory root.
  ///
  /// - Returns: the URL of the downloaded `.xlsx` file.
  public func downloadACD() async throws -> URL {
    try await acdDownloader.download(
      into: workingDirectory,
      progressCallback: progressCallback
    )
  }

  /// Downloads every EUROCONTROL APD detail page into the `apd/`
  /// subdirectory of the working directory.
  ///
  /// - Parameter errorCallback: Invoked once per per-ICAO failure; the
  ///   download continues. Defaults to a no-op.
  /// - Returns: the URL of the `apd/` subdirectory.
  public func downloadAPD(
    errorCallback: @escaping @Sendable (Error) -> Void = { _ in }
  ) async throws -> URL {
    let APDDirectory = workingDirectory.appendingPathComponent("apd", isDirectory: true)
    return try await apdDownloader.download(
      into: APDDirectory,
      progressCallback: progressCallback,
      errorCallback: errorCallback
    )
  }

  /// Downloads both data sources concurrently.
  ///
  /// - Parameter errorCallback: Forwarded to ``downloadAPD(errorCallback:)``.
  ///   Defaults to a no-op.
  /// - Returns: the working directory containing the ACD workbook at the root
  ///   and the APD pages under `apd/`.
  public func downloadAll(
    errorCallback: @escaping @Sendable (Error) -> Void = { _ in }
  ) async throws -> URL {
    async let ACD = downloadACD()
    async let APD = downloadAPD(errorCallback: errorCallback)
    _ = try await (ACD, APD)
    return workingDirectory
  }
}
