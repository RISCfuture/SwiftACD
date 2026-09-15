public import Foundation

/// Reads a previously-downloaded FAA ACD workbook and EUROCONTROL APD
/// detail-page directory and assembles the composite ``AircraftProfile``
/// dictionary keyed by ICAO type designator.
///
/// The expected on-disk layout (produced by ``Downloader``):
///
/// ```
/// <directory>/
///   <faa>.xlsx          // any single .xlsx file at the root
///   apd/
///     <ICAO>.html       // one detail page per aircraft
///     ...
/// ```
///
/// Either source may be absent; ``parse(progress:errorCallback:)`` will
/// surface what it can. Per-record errors are routed to `errorCallback` and
/// parsing continues; only fatal I/O errors propagate via `throws`.
///
/// To follow the parse, hand it a `Subprogress` from your own
/// `ProgressManager`:
///
/// ```swift
/// let manager = ProgressManager(totalCount: 100)
/// let profiles = try await parser.parse(
///   progress: manager.subprogress(assigningCount: 100),
///   errorCallback: { _ in }
/// )
/// ```
public struct Parser: Sendable {

  /// Callback invoked once for every per-record error encountered. Parsing
  /// continues regardless.
  public typealias ErrorCallback = @Sendable (_ error: any Error) -> Void

  /// Working directory holding the FAA workbook and APD subdirectory.
  public let directory: URL

  /// Designated initializer.
  ///
  /// - Parameter directory: A directory previously populated by
  ///   ``Downloader/downloadAll(progress:errorCallback:)`` or its constituent methods.
  public init(directory: URL) {
    self.directory = directory
  }

  /// Parse the directory and return the merged composite profiles.
  ///
  /// - Parameter progress: Optional progress sink. The FAA and EUROCONTROL legs
  ///   are weighted by their on-disk byte totals, so the reported fraction
  ///   tracks the work remaining rather than the number of sources left.
  /// - Parameter errorCallback: Per-record error sink.
  /// - Returns: A dictionary of ``AircraftProfile`` keyed by ICAO type
  ///   designator.
  public func parse(
    progress: consuming Subprogress? = nil,
    errorCallback: @escaping ErrorCallback
  ) async throws -> [String: AircraftProfile] {
    let ACD_URL = try findACDWorkbook()
    let APD_URL = directory.appendingPathComponent("apd", isDirectory: true)

    let ACDSize = Int(fileSize(of: ACD_URL))
    let APDSize = Int(totalSize(of: APD_URL))

    // Both legs run concurrently, so each gets its own `ProgressManager` wired
    // in by reporter — a `Subprogress` could not be captured by the task
    // group's escaping closures.
    // Byte counts are recorded on the leaves only: `summary(of:)` sums the
    // whole subtree, so a value on the parent as well would double-count.
    let parent = progress?.start(totalCount: byteTotal(ACDSize + APDSize))
    let ACDProgress = parent?.child(assigningCount: ACDSize, totalCount: byteTotal(ACDSize))
    ACDProgress?.totalByteCount = UInt64(ACDSize)
    let APDProgress = parent?.child(assigningCount: APDSize)

    let database = AircraftDatabase()

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask { [ACD_URL] in
        let parser = ACDParser(url: ACD_URL)
        let rows = try parser.parse(errorCallback: errorCallback)
        await database.add(ACDRows: rows)
        // CoreXLSX parses the workbook in one shot, so the leg reports as a
        // single step rather than incrementally.
        ACDProgress?.completedByteCount = UInt64(ACDSize)
        ACDProgress?.finish()
      }
      group.addTask { [APD_URL] in
        guard FileManager.default.fileExists(atPath: APD_URL.path) else {
          APDProgress?.finish()
          return
        }
        let parser = APDParser(directory: APD_URL)
        let records = try await parser.parse(
          progress: APDProgress,
          errorCallback: errorCallback
        )
        await database.add(APDRecords: records)
        // Per-file byte totals exclude anything the parser skipped, so settle
        // the leg rather than leaving a rounding gap.
        APDProgress?.finish()
      }
      try await group.waitForAll()
    }

    return await database.merged()
  }

  // `ProgressManager` reports a `fractionCompleted` of NaN for a total of zero,
  // so an empty source is modelled as indeterminate instead.
  private func byteTotal(_ bytes: Int) -> Int? { bytes > 0 ? bytes : nil }

  private func fileSize(of url: URL) -> Int64 {
    (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
  }

  private func findACDWorkbook() throws -> URL {
    let manager = FileManager.default
    let contents: [URL]
    do {
      contents = try manager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    } catch {
      throw SwiftACDError.fileNotFound(url: directory)
    }
    guard let xlsx = contents.first(where: { $0.pathExtension.lowercased() == "xlsx" }) else {
      throw SwiftACDError.fileNotFound(url: directory.appendingPathComponent("*.xlsx"))
    }
    return xlsx
  }

  private func totalSize(of directory: URL) -> Int64 {
    let manager = FileManager.default
    guard
      let enumerator = manager.enumerator(
        at: directory,
        includingPropertiesForKeys: [.fileSizeKey],
        options: [.skipsHiddenFiles]
      )
    else { return 0 }
    var total: Int64 = 0
    for case let url as URL in enumerator {
      let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
      total += Int64(size)
    }
    return total
  }
}
