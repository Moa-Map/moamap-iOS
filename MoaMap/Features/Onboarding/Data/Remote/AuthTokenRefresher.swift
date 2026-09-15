import Foundation

/// 인증을 적용하지 않은 클라이언트를 주입한다. 갱신 요청의 401은 다시 갱신하지 않는다.
nonisolated struct AuthTokenRefresher: TokenRefresher {
    private struct RefreshRequest: Encodable { let refreshToken: String }
    private struct TokenResponse: Decodable {
        let accessToken: String?
        let refreshToken: String?
    }

    let client: APIClient

    func refresh(refreshToken: String) async throws -> TokenRefreshResult {
        do {
            let request = APIRequest(
                path: ["api", "v1", "auth", "token", "refresh"], method: .post,
                jsonBody: try JSONEncoder().encode(RefreshRequest(refreshToken: refreshToken))
            )
            let response = try await client.send(request, as: TokenResponse.self)
            guard let accessToken = response.accessToken, !accessToken.isEmpty else { return .failed }
            return .success(AuthToken(
                accessToken: accessToken,
                refreshToken: response.refreshToken.flatMap { $0.isEmpty ? nil : $0 } ?? refreshToken
            ))
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as NetworkError {
            try Task.checkCancellation()
            switch error {
            // Android와 동일하게 HTTP/서버 오류 응답은 거부로, 연결/응답 해석 오류는 일시적 실패로 분류한다.
            case .http, .server: return .rejected
            default: return .failed
            }
        } catch {
            try Task.checkCancellation()
            return .failed
        }
    }
}
