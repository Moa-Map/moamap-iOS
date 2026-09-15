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
            // 인증 거부만 세션을 끝낸다. 서버 장애·요청 제한·알 수 없는 오류는 세션을 유지한다.
            case .http(let status), .server(_, let status):
                return [401, 403].contains(status) ? .rejected : .failed
            default: return .failed
            }
        } catch {
            try Task.checkCancellation()
            return .failed
        }
    }
}
