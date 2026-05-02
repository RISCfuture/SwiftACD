import Foundation

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
public struct Parser: Sendable {

  /// Callback invoked once for every per-record error encountered. Parsing
  /// continues regardless.
  public typealias ErrorCallback = @Sendable (_ error: Error) -> Void

  /// Working directory holding the FAA workbook and APD subdirectory.
  public let directory: URL

  /// Designated initializer.
  ///
  /// - Parameter directory: A directory previously populated by
  ///   ``Downloader/downloadAll()`` or its constituent methods.
  public init(directory: URL) {
    self.directory = directory
  }

  /// Parse the directory and return the merged composite profiles.
  ///
  /// - Parameter progress: Optional progress sink. Total bytes are sized
  ///   from the FAA workbook plus the sum of every APD `.html` file's size.
  /// - Parameter errorCallback: Per-record error sink.
  /// - Returns: A dictionary of ``AircraftProfile`` keyed by ICAO type
  ///   designator.
  public func parse(
    progress: AsyncProgress? = nil,
    errorCallback: @escaping ErrorCallback
  ) async throws -> [String: AircraftProfile] {
    let ACD_URL = try findACDWorkbook()
    let APD_URL = directory.appendingPathComponent("apd", isDirectory: true)

    let ACDSize =
      (try? FileManager.default.attributesOfItem(atPath: ACD_URL.path)[.size] as? Int64) ?? 0
    let APDSize = totalSize(of: APD_URL)
    if let progress {
      await progress.setTotalBytes(ACDSize + APDSize)
    }

    let database = AircraftDatabase()

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask { [ACD_URL] in
        let parser = ACDParser(url: ACD_URL)
        let rows = try parser.parse(errorCallback: errorCallback)
        await database.add(ACDRows: rows)
        if let progress {
          await progress.addBytes(ACDSize)
        }
      }
      group.addTask { [APD_URL] in
        guard FileManager.default.fileExists(atPath: APD_URL.path) else { return }
        let parser = APDParser(directory: APD_URL)
        let records = try await parser.parse(errorCallback: errorCallback)
        await database.add(APDRecords: records)
        if let progress {
          await progress.addBytes(APDSize)
        }
      }
      try await group.waitForAll()
    }

    return await database.merged()
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
