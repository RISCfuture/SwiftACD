import Foundation
import Testing

@testable import SwiftACD

@Suite("Parser facade")
struct ParserIntegrationTests {

  /// Build a working directory containing the fixture xlsx and APD html
  /// files in the layout `Parser` expects.
  static func makeFixtureDirectory() throws -> URL {
    let resources = try #require(Bundle.module.resourceURL).appendingPathComponent("TestResources")
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftACDTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let acd = dir.appendingPathComponent("acd.xlsx")
    try FileManager.default.copyItem(
      at: resources.appendingPathComponent("sample_acd.xlsx"),
      to: acd
    )

    let APDDir = dir.appendingPathComponent("apd", isDirectory: true)
    try FileManager.default.createDirectory(at: APDDir, withIntermediateDirectories: true)
    for ICAO in ["A320", "B738", "B748", "C172", "EC25"] {
      try FileManager.default.copyItem(
        at: resources.appendingPathComponent("apd_\(ICAO).html"),
        to: APDDir.appendingPathComponent("\(ICAO).html")
      )
    }
    return dir
  }

  @Test("Parses ACD + APD into composite profiles keyed by ICAO")
  func endToEnd() async throws {
    let dir = try Self.makeFixtureDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let parser = Parser(directory: dir)
    let profiles = try await parser.parse(errorCallback: { _ in })

    // ICAOs from both sources should be present
    #expect(profiles["A320"] != nil)
    #expect(profiles["B738"] != nil)
    #expect(profiles["C172"] != nil)
    #expect(profiles["B748"] != nil)
    #expect(profiles["GLF6"] != nil)  // ACD-only
    #expect(profiles["EC25"] != nil)  // APD-only (sparse)

    // A320 should be sourced from both
    let a320 = try #require(profiles["A320"])
    #expect(a320.sources.contains(.ACD))
    #expect(a320.sources.contains(.APD))
    #expect(a320.identity.IATACodes.contains("320"))
    #expect(a320.categories.wakeTurbulence == .medium)
    #expect(a320.categories.RECAT_EU == .upperMedium)
    #expect(a320.performance?.takeoff?.v2Kt == 145)

    // FAA wins for overlapping fields — A320 ACD MTOW is 169755 lbs.
    // APD MTOW is 73900 kg ≈ 162929 lbs. Composite should be the FAA value.
    #expect(a320.weights?.MTOWLb == 169_755)

    // Variant fan-out for B738
    let b738 = try #require(profiles["B738"])
    #expect(b738.variants.count == 2)
    #expect(b738.variants.contains { $0.model == "737-800" })
    #expect(b738.variants.contains { $0.model == "737-800W" })

    // GLF6 has no APD — sources should be ACD-only
    let glf6 = try #require(profiles["GLF6"])
    #expect(glf6.sources == .ACD)
    #expect(glf6.performance == nil)

    // EC25 has no ACD — sources should be APD-only
    let ec25 = try #require(profiles["EC25"])
    #expect(ec25.sources == .APD)
  }

  @Test("Progress reaches total bytes")
  func progressCompletes() async throws {
    let dir = try Self.makeFixtureDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let progress = AsyncProgress()
    let parser = Parser(directory: dir)
    _ = try await parser.parse(progress: progress, errorCallback: { _ in })

    let completed = await progress.completed
    let total = await progress.total
    #expect(total > 0)
    #expect(completed == total)
  }
}
