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

    static func validate(_ data: Data, statusCode: Int) throws {
        let metadata = try decodeJSON(Metadata.self, from: data)
        guard metadata.success == true else {
            throw metadata.error?.networkError(fallbackStatus: statusCode)
                ?? NetworkError.server(code: "UNKNOWN", statusCode: statusCode)
        }
    }

    static func decode<Value: Decodable>(_ data: Data, as type: Value.Type, statusCode: Int) throws -> Value {
        try validate(data, statusCode: statusCode)
        let payload = try decodeJSON(Payload<Value>.self, from: data)
        guard let value = payload.data else { throw NetworkError.emptyData }
        return value
    }

    private static func decodeJSON<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        try Task.checkCancellation()
        do {
            let value = try JSONDecoder().decode(type, from: data)
            try Task.checkCancellation()
            return value
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // 디코딩 도중 취소된 요청은 일반 오류로 화면 상태를 덮지 않는다.
            try Task.checkCancellation()
            throw NetworkError.decoding
        }
    }
}
