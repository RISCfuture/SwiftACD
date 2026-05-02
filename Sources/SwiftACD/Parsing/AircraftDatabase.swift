import Foundation

actor AircraftDatabase {
  private var ACDRows: [ACDRow] = []
  private var APDRecords: [String: APDRecord] = [:]

  func add(ACDRows: [ACDRow]) {
    self.ACDRows.append(contentsOf: ACDRows)
  }

  func add(APDRecords: [String: APDRecord]) {
    self.APDRecords.merge(APDRecords) { _, new in new }
  }

  func merged() -> [String: AircraftProfile] {
    Builder.build(ACDRows: ACDRows, APDRecords: APDRecords)
  }
}
