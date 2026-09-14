import Foundation

nonisolated struct APIRequest: Sendable {
    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    /// 각 요소는 인코딩되지 않은 경로 세그먼트다.
    let path: [String]
    var method: Method = .get
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var jsonBody: Data? = nil

    func urlRequest(baseURL: URL) throws -> URLRequest {
        guard path.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("/") }) else {
            throw NetworkError.invalidRequest
        }
        let url = path.reduce(baseURL) { $0.appendingPathComponent($1) }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidRequest
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let requestURL = components.url else { throw NetworkError.invalidRequest }
        var request = URLRequest(url: requestURL)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let jsonBody {
            request.httpBody = jsonBody
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        return request
    }
}
