import Foundation

nonisolated struct APIClient: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let configuration: APIConfiguration
    private let transport: Transport

    init(configuration: APIConfiguration, session: URLSession) {
        self.init(configuration: configuration) { request in
            try await session.data(for: request)
        }
    }

    init(configuration: APIConfiguration, transport: @escaping Transport) {
        self.configuration = configuration
        self.transport = transport
    }

    /// 공통 응답 envelope 해석은 전송 처리와 별도로 구성한다.
    func send(_ request: APIRequest) async throws -> Data {
        try Task.checkCancellation()
        let urlRequest = try request.urlRequest(baseURL: configuration.baseURL)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport(urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            if error.code == .cancelled || Task.isCancelled { throw CancellationError() }
            throw NetworkError.connection(error.code)
        } catch {
            try Task.checkCancellation()
            throw error
        }
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            throw NetworkError.http(statusCode: response.statusCode)
        }
        return data
    }
}
