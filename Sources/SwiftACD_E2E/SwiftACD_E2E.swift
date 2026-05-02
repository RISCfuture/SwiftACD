import ArgumentParser
import Foundation
import SwiftACD

@main
struct SwiftACD_E2E: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swift-acd",
    abstract: "Download and parse the FAA ACD + EUROCONTROL APD into composite aircraft profiles.",
    subcommands: [Download.self, Parse.self]
  )
}

// MARK: - download

extension SwiftACD_E2E {
  struct Download: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Download the FAA ACD workbook and EUROCONTROL APD detail pages."
    )

    @Option(name: .shortAndLong, help: "Directory to download into.")
    var output: String

    func run() async throws {
      let outputURL = URL(fileURLWithPath: output)
      try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

      print("Downloading ACD workbook…")
      let downloader = try Downloader(workingDirectory: outputURL)
      let ACD = try await downloader.downloadACD()
      print("  saved \(ACD.lastPathComponent)")

      print("Downloading APD detail pages (this may take a few minutes)…")
      let APD = try await downloader.downloadAPD()
      let count =
        (try? FileManager.default.contentsOfDirectory(atPath: APD.path).filter {
          $0.hasSuffix(".html") && $0 != "listpage.html"
        }.count) ?? 0
      print("  saved \(count) page(s) to \(APD.path)")
      print("Done.")
    }
  }
}

// MARK: - parse

extension SwiftACD_E2E {
  struct Parse: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract:
        "Parse a previously-downloaded directory and print or export the composite profiles."
    )

    @Argument(help: "Path to a directory previously populated by `download`.")
    var directory: String

    @Flag(help: "Emit JSON for the full profile dictionary on stdout.")
    var json: Bool = false

    @Option(help: "If set, print the full profile for this ICAO designator and exit.")
    var ICAO: String?

    func run() async throws {
      let dir = URL(fileURLWithPath: directory)
      let parser = Parser(directory: dir)

      let progress = AsyncProgress()
      let monitor = Task {
        var lastPercent = -1
        while !Task.isCancelled {
          let percent = Int((await progress.percentDone) ?? 0)
          if percent != lastPercent {
            FileHandle.standardError.write(Data("\rparsing: \(percent)%   ".utf8))
            lastPercent = percent
          }
          if await progress.isFinished { break }
          try? await Task.sleep(for: .milliseconds(100))
        }
      }

      let errorCount = ErrorCounter()
      let profiles = try await parser.parse(
        progress: progress,
        errorCallback: { error in
          Task { await errorCount.add(error) }
        }
      )
      monitor.cancel()
      print("")
      let totalErrors = await errorCount.total
      FileHandle.standardError.write(
        Data("Parsed \(profiles.count) profile(s), \(totalErrors) per-record error(s).\n".utf8)
      )

      if let ICAO {
        guard let profile = profiles[ICAO] else {
          throw ValidationError(
            "No profile for ICAO \(ICAO). Try one of: \(profiles.keys.sorted().prefix(20).joined(separator: ", "))…"
          )
        }
        try emitJSON(profile)
        return
      }

      if json {
        try emitJSON(profiles)
        return
      }

      for key in profiles.keys.sorted() {
        guard let p = profiles[key] else { continue }
        let mfr = p.identity.manufacturer ?? "?"
        let model = p.identity.model ?? "?"
        let MTOW = p.weights.map { "\(Int($0.MTOWLb)) lbs" } ?? "?"
        let sources = sourceList(p.sources)
        print(
          "\(key.padding(toLength: 6, withPad: " ", startingAt: 0)) \(mfr) \(model) — \(MTOW) [\(sources)]"
        )
      }
    }

    private func emitJSON<T: Encodable>(_ value: T) throws {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(value)
      FileHandle.standardOutput.write(data)
      FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private func sourceList(_ source: Source) -> String {
      var parts: [String] = []
      if source.contains(.ACD) { parts.append("ACD") }
      if source.contains(.APD) { parts.append("APD") }
      return parts.joined(separator: "+")
    }
  }
}

// MARK: - helpers

private actor ErrorCounter {
  private(set) var total: Int = 0

  func add(_ error: Error) {
    total += 1
    let detail =
      (error as? LocalizedError)?.failureReason
      ?? (error as NSError).localizedFailureReason
      ?? error.localizedDescription
    FileHandle.standardError.write(Data("warning: \(detail)\n".utf8))
  }
}
