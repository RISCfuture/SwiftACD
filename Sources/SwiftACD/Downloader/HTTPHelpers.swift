import Foundation

// FAA rejects scripted clients without a browser-shaped UA.
let defaultUserAgent =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

func ensureHTTPSuccess(
  request: URLRequest,
  response: URLResponse
) throws {
  guard let http = response as? HTTPURLResponse,
    (200..<300).contains(http.statusCode)
  else {
    throw SwiftACDError.networkError(request: request, response: response)
  }
}
