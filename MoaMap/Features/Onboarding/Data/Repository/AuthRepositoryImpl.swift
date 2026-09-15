import Foundation

@MainActor
final class AuthRepositoryImpl: AuthRepository {
    private let client: APIClient
    private let kakaoLogin: () async throws -> String
    private let tokenStore: any AuthTokenStore
    private let currentUserStore: any CurrentUserStore

    init(client: APIClient, kakaoLogin: @escaping () async throws -> String, tokenStore: any AuthTokenStore, currentUserStore: any CurrentUserStore) {
        self.client = client
        self.kakaoLogin = kakaoLogin
        self.tokenStore = tokenStore
        self.currentUserStore = currentUserStore
    }

    func loginWithKakao() async throws {
        try Task.checkCancellation()
        let kakaoAccessToken = try await kakaoLogin()
        try Task.checkCancellation()
        guard !kakaoAccessToken.isEmpty else { throw LoginError.invalidResponse }
        let request = APIRequest(
            path: ["api", "v1", "auth", "kakao", "login"], method: .post,
            jsonBody: try JSONEncoder().encode(KakaoLoginRequest(kakaoAccessToken: kakaoAccessToken))
        )
        let response = try await client.send(request, as: KakaoLoginResponse.self)
        try Task.checkCancellation()
        guard let userId = response.userId, userId > 0,
              let accessToken = response.accessToken, !accessToken.isEmpty,
              let refreshToken = response.refreshToken, !refreshToken.isEmpty else {
            throw LoginError.invalidResponse
        }

        // await 없이 신원을 먼저 저장하고 토큰 저장으로 세션을 완성한다.
        do {
            try currentUserStore.save(userId: userId)
            try tokenStore.save(AuthToken(accessToken: accessToken, refreshToken: refreshToken))
        } catch {
            // 한 저장소가 실패해도 나머지 정리를 시도한다. 원래 저장 오류는 호출자에게 전파한다.
            try? tokenStore.clear()
            try? currentUserStore.clear()
            throw error
        }
    }

    func hasSession() throws -> Bool {
        guard let token = try tokenStore.load(), token.isValid,
              let userId = try currentUserStore.load(), userId > 0 else { return false }
        return true
    }
}
