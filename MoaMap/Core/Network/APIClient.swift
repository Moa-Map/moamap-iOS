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

    func send<Value: Decodable & Sendable>(_ request: APIRequest, as type: Value.Type) async throws -> Value {
        let response = try await perform(request)
        let value = try APIResponseDecoder.decode(response.data, as: type, statusCode: response.statusCode)
        try Task.checkCancellation()
        return value
    }

    /// data 없는 성공 envelope 또는 비어 있는 2xx 응답을 처리한다.
    func sendWithoutResponse(_ request: APIRequest) async throws {
        let response = try await perform(request)
        if !response.data.isEmpty {
            try APIResponseDecoder.validate(response.data, statusCode: response.statusCode)
        }
        try Task.checkCancellation()
    }

    /// 카카오 등 공통 envelope를 사용하지 않는 API에도 쓸 수 있는 원문 응답.
    func send(_ request: APIRequest) async throws -> Data {
        try await perform(request).data
    }

    private func perform(_ request: APIRequest) async throws -> (data: Data, statusCode: Int) {
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
            throw APIResponseDecoder.httpError(data: data, statusCode: response.statusCode)
        }
        return (data, response.statusCode)
    }
}
