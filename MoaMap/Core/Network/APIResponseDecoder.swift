import Foundation

/// 오류 여부를 먼저 읽어 실패 응답의 data 형태에 영향을 받지 않는다.
nonisolated enum APIResponseDecoder {
    private struct Metadata: Decodable {
        let success: Bool?
        let error: ServerError?
    }

    private struct ServerError: Decodable {
        let code: String?
        let status: Int?

        func networkError(fallbackStatus: Int) -> NetworkError {
            .server(code: code ?? "UNKNOWN", statusCode: status.flatMap { $0 == 0 ? nil : $0 } ?? fallbackStatus)
        }
    }

    private struct Payload<Value: Decodable>: Decodable {
        let data: Value?
    }

    static func httpError(data: Data, statusCode: Int) -> NetworkError {
        // HTTP 실패에서는 success/data와 무관하게 error 필드만 읽는다.
        struct ErrorEnvelope: Decodable { let error: ServerError? }
        let error = try? JSONDecoder().decode(ErrorEnvelope.self, from: data).error
        return error?.networkError(fallbackStatus: statusCode) ?? .http(statusCode: statusCode)
    }

    static func validate(_ data: Data) throws {
        let metadata: Metadata
        do { metadata = try JSONDecoder().decode(Metadata.self, from: data) }
        catch { throw NetworkError.decoding }
        guard metadata.success == true else {
            throw metadata.error?.networkError(fallbackStatus: 200)
                ?? NetworkError.server(code: "UNKNOWN", statusCode: 200)
        }
    }

    static func decode<Value: Decodable>(_ data: Data, as type: Value.Type) throws -> Value {
        try validate(data)
        let payload: Payload<Value>
        do { payload = try JSONDecoder().decode(Payload<Value>.self, from: data) }
        catch { throw NetworkError.decoding }
        guard let value = payload.data else { throw NetworkError.emptyData }
        return value
    }
}
