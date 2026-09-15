public import Foundation

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
///
/// To follow the download, hand any method a `Subprogress` obtained from your
/// own `ProgressManager`:
///
/// ```swift
/// let manager = ProgressManager(totalCount: 100)
/// let directory = try await downloader.downloadAll(
///   progress: manager.subprogress(assigningCount: 100)
/// )
/// ```
public struct Downloader: Sendable {

  /// The directory all artifacts are written into.
  public let workingDirectory: URL

  private let acdDownloader: ACDDownloader
  private let apdDownloader: APDDownloader

  /// Creates a downloader.
  ///
  /// - Parameter workingDirectory: Destination for the ACD workbook (root) and
  ///   the APD pages (`apd/` subdirectory). When `nil`, a unique temporary
  ///   directory is used.
  public init(workingDirectory: URL? = nil) throws {
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
    self.acdDownloader = ACDDownloader()
    self.apdDownloader = APDDownloader()
  }

  /// Downloads the FAA ACD workbook to the working-directory root.
  ///
  /// - Parameter progress: Optional progress sink. Reports bytes received, and
  ///   stays indeterminate until the server declares a content length.
  /// - Returns: the URL of the downloaded `.xlsx` file.
  public func downloadACD(progress: consuming Subprogress? = nil) async throws -> URL {
    try await acdDownloader.download(
      into: workingDirectory,
      progress: progress?.start(totalCount: nil)
    )
  }

  /// Downloads every EUROCONTROL APD detail page into the `apd/`
  /// subdirectory of the working directory.
  ///
  /// - Parameters:
  ///   - progress: Optional progress sink. Reports detail pages fetched, and
  ///     stays indeterminate until the list page has been enumerated.
  ///   - errorCallback: Invoked once per per-ICAO failure; the download
  ///     continues. Defaults to a no-op.
  /// - Returns: the URL of the `apd/` subdirectory.
  public func downloadAPD(
    progress: consuming Subprogress? = nil,
    errorCallback: @escaping @Sendable (any Error) -> Void = { _ in }
  ) async throws -> URL {
    let APDDirectory = workingDirectory.appendingPathComponent("apd", isDirectory: true)
    return try await apdDownloader.download(
      into: APDDirectory,
      progress: progress?.start(totalCount: nil),
      errorCallback: errorCallback
    )
  }

  /// Downloads both data sources concurrently.
  ///
  /// - Parameters:
  ///   - progress: Optional progress sink. The two downloads are weighted
  ///     equally, since neither source's size is known before it is fetched.
  ///   - errorCallback: Forwarded to ``downloadAPD(progress:errorCallback:)``.
  ///     Defaults to a no-op.
  /// - Returns: the working directory containing the ACD workbook at the root
  ///   and the APD pages under `apd/`.
  public func downloadAll(
    progress: consuming Subprogress? = nil,
    errorCallback: @escaping @Sendable (any Error) -> Void = { _ in }
  ) async throws -> URL {
    let parent = progress?.start(totalCount: 2)
    let ACDProgress = parent?.child(assigningCount: 1)
    let APDProgress = parent?.child(assigningCount: 1)

    let APDDirectory = workingDirectory.appendingPathComponent("apd", isDirectory: true)
    async let ACD = acdDownloader.download(
      into: workingDirectory,
      progress: ACDProgress
    )
    async let APD = apdDownloader.download(
      into: APDDirectory,
      progress: APDProgress,
      errorCallback: errorCallback
    )
    _ = try await (ACD, APD)
    return workingDirectory
  }
}
