import Foundation

nonisolated struct APIClient: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let configuration: APIConfiguration
    private let transport: Transport
    private let authSession: AuthSession?

    init(configuration: APIConfiguration, session: URLSession) {
        self.init(configuration: configuration) { request in
            try await session.data(for: request)
        }
    }

    init(configuration: APIConfiguration, authSession: AuthSession? = nil, transport: @escaping Transport) {
        self.configuration = configuration
        self.authSession = authSession
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
        var urlRequest = try request.urlRequest(baseURL: configuration.baseURL)
        let excludesAuth = ["/api/v1/auth/kakao/login", "/api/v1/auth/token/refresh"].contains(urlRequest.url?.path)
        let session = excludesAuth ? nil : authSession
        let credentials = try await session?.credentials()
        if let credentials {
            urlRequest.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        }
        let initial = try await transfer(urlRequest)
        if initial.statusCode == 401, let session, let credentials,
           let refreshed = try await session.refresh(for: credentials) {
            try Task.checkCancellation()
            urlRequest.setValue("Bearer \(refreshed)", forHTTPHeaderField: "Authorization")
            return try validate(try await transfer(urlRequest))
        }
        return try validate(initial)
    }

    private func transfer(_ urlRequest: URLRequest) async throws -> (data: Data, statusCode: Int) {
        try Task.checkCancellation()
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
        return (data, response.statusCode)
    }

    private func validate(_ response: (data: Data, statusCode: Int)) throws -> (data: Data, statusCode: Int) {
        try Task.checkCancellation()
        guard (200..<300).contains(response.statusCode) else {
            throw APIResponseDecoder.httpError(data: response.data, statusCode: response.statusCode)
        }
        return response
    }
}
