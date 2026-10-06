import Foundation

nonisolated enum NetworkError: Error, Equatable, Sendable {
    case invalidRequest
    case invalidResponse
    case connection(URLError.Code)
    case http(statusCode: Int)
    /// `message` 는 서버가 준 안내 문구다. `userMessage` 에는 쓰지 않고, 필요한 화면만 골라 쓴다.
    case server(code: String, statusCode: Int, message: String? = nil)
    case emptyData
    case decoding

    /// 서버가 준 안내 문구. 코드·상태 없이 문구만 있고, 비어 있으면 nil 이다.
    var serverMessage: String? {
        guard case .server(_, _, let message?) = self else { return nil }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 서버 원문 대신 화면에서 사용할 수 있는 공통 안내 문구.
    var userMessage: String {
        switch self {
        case .connection:
            "네트워크 연결을 확인해 주세요."
        case .http, .server:
            "요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."
        case .invalidRequest, .invalidResponse, .emptyData, .decoding:
            "데이터를 불러오지 못했습니다. 다시 시도해 주세요."
        }
    }
}
