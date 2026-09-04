import Foundation
import Testing

@testable import SwiftACD

@Suite
struct `ACD parser` {

  static func fixture() throws -> URL {
    let resources = try #require(Bundle.module.resourceURL)
    return resources.appendingPathComponent("TestResources/sample_acd.xlsx")
  }

  @Test
  func `parses every well-formed row from the fixture workbook`() throws {
    var errors: [any Error] = []
    let parser = ACDParser(url: try Self.fixture())
    let rows = try parser.parse(errorCallback: { errors.append($0) })

    let ICAOs = rows.map(\.ICAOTypeDesignator)
    #expect(ICAOs.contains("B738"))
    #expect(ICAOs.contains("A320"))
    #expect(ICAOs.contains("C172"))
    #expect(ICAOs.contains("B748"))
    #expect(ICAOs.contains("DH8D"))
    #expect(ICAOs.contains("GLF6"))
  }

  @Test
  func `surfaces multiple variants for B738`() throws {
    let parser = ACDParser(url: try Self.fixture())
    let rows = try parser.parse(errorCallback: { _ in })
    let b738 = rows.filter { $0.ICAOTypeDesignator == "B738" }
    #expect(b738.count == 2)
    #expect(b738.contains { $0.model == "737-800" })
    #expect(b738.contains { $0.model == "737-800W" })
  }

  @Test
  func `decodes typed numeric fields and enums`() throws {
    let parser = ACDParser(url: try Self.fixture())
    let rows = try parser.parse(errorCallback: { _ in })
    let a320 = try #require(rows.first { $0.ICAOTypeDesignator == "A320" })

    #expect(a320.manufacturer == "Airbus")
    #expect(a320.approachCategory == .c)
    #expect(a320.designGroup == .III)
    #expect(a320.taxiwayDesignGroup == .group3)
    #expect(a320.MTOWLb == 169_755)
    #expect(a320.wingspanFt == 111.8)
    #expect(a320.lengthFt == 123.3)
    #expect(a320.tailHeightFt == 38.6)
    #expect(a320.mainGearWidthFt == 24.6)
    #expect(a320.cockpitToMainGearFt == 41.7)
    #expect(a320.approachSpeedKt == 138)
  }

  @Test
  func `assigns ADG VI and TDG 7 to heavy aircraft`() throws {
    let parser = ACDParser(url: try Self.fixture())
    let rows = try parser.parse(errorCallback: { _ in })
    let b748 = try #require(rows.first { $0.ICAOTypeDesignator == "B748" })
    #expect(b748.designGroup == .VI)
    #expect(b748.taxiwayDesignGroup == .group7)
    #expect(b748.approachCategory == .d)
  }

  @Test
  func `skips a row whose ADG raw value is unknown and reports it to the error callback`() throws {
    var errors: [any Error] = []
    let parser = ACDParser(url: try Self.fixture())
    let rows = try parser.parse(errorCallback: { errors.append($0) })

    #expect(!rows.contains(where: { $0.ICAOTypeDesignator == "XXXX" }))
    #expect(
      errors.contains { error in
        guard case let SwiftACDError.unknownAirplaneDesignGroup(rawValue: raw, context: _) = error
        else { return false }
        return raw == "ZZZ"
      }
    )
  }
}
