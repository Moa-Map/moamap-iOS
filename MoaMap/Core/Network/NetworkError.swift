import Foundation

nonisolated enum NetworkError: Error, Equatable, Sendable {
    case invalidRequest
    case invalidResponse
    case connection(URLError.Code)
    case http(statusCode: Int)
}
