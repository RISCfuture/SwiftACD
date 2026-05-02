import Foundation

enum ParsingHelpers {

  // Tolerates thousands separators (`,` or space) and trailing unit suffixes
  // (e.g. `"174,200"`, `"49 ft"`, `"34.1 m"`). A single leading `-` and a
  // single `.` are allowed.
  static func parseDouble(_ string: String) -> Double? {
    var stripped = ""
    var sawDigit = false
    var sawDot = false
    for scalar in string.unicodeScalars {
      if scalar == "-" && stripped.isEmpty {
        stripped.unicodeScalars.append(scalar)
      } else if scalar == "." && !sawDot {
        stripped.unicodeScalars.append(scalar)
        sawDot = true
      } else if CharacterSet.decimalDigits.contains(scalar) {
        stripped.unicodeScalars.append(scalar)
        sawDigit = true
      } else if scalar == "," || scalar == " " {
        continue
      } else if sawDigit {
        break
      }
    }
    return sawDigit ? Double(stripped) : nil
  }
}
