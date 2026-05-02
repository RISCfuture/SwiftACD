import Foundation
import Testing

@testable import SwiftACD

@Suite("ACD parser")
struct ACDParserTests {

  static func fixture() throws -> URL {
    let resources = try #require(Bundle.module.resourceURL)
    return resources.appendingPathComponent("TestResources/sample_acd.xlsx")
  }

  @Test("Parses every well-formed row from the fixture workbook")
  func parsesFixture() throws {
    var errors: [Error] = []
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

  @Test("Surfaces multiple variants for B738")
  func b738Variants() throws {
    let parser = ACDParser(url: try Self.fixture())
    let rows = try parser.parse(errorCallback: { _ in })
    let b738 = rows.filter { $0.ICAOTypeDesignator == "B738" }
    #expect(b738.count == 2)
    #expect(b738.contains { $0.model == "737-800" })
    #expect(b738.contains { $0.model == "737-800W" })
  }

  @Test("Decodes typed numeric fields and enums")
  func decodesA320() throws {
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

  @Test("Heavy aircraft surface ADG VI / TDG 7")
  func b748Categories() throws {
    let parser = ACDParser(url: try Self.fixture())
    let rows = try parser.parse(errorCallback: { _ in })
    let b748 = try #require(rows.first { $0.ICAOTypeDesignator == "B748" })
    #expect(b748.designGroup == .VI)
    #expect(b748.taxiwayDesignGroup == .group7)
    #expect(b748.approachCategory == .d)
  }

  @Test("Unknown ADG raw value triggers error callback and skips row")
  func unknownADGRawValue() throws {
    var errors: [Error] = []
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
