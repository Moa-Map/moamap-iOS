import Foundation

@MainActor
final class AuthRepositoryImpl: AuthRepository {
    private let client: APIClient
    private let kakaoLogin: () async throws -> String
    private let appleLogin: (String) async throws -> AppleLoginCredential
    private let tokenStore: any AuthTokenStore
    private let currentUserStore: any CurrentUserStore

    init(client: APIClient, kakaoLogin: @escaping () async throws -> String,
         appleLogin: @escaping (String) async throws -> AppleLoginCredential = { _ in throw LoginError.notConfigured },
         tokenStore: any AuthTokenStore, currentUserStore: any CurrentUserStore) {
        self.client = client
        self.kakaoLogin = kakaoLogin
        self.appleLogin = appleLogin
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
        let response = try await client.send(request, as: LoginResponse.self)
        try saveSession(response)
    }

    func loginWithApple() async throws {
        try Task.checkCancellation()
        let nonceRequest = APIRequest(path: ["api", "v1", "auth", "apple", "nonce"], method: .post)
        let response = try await client.send(nonceRequest, as: AppleNonceResponse.self)
        try Task.checkCancellation()
        guard response.expiresIn > 0,
              response.nonce.utf8.count == 43,
              response.nonce.utf8.allSatisfy({
                  (65...90).contains($0) || (97...122).contains($0)
                      || (48...57).contains($0) || $0 == 45 || $0 == 95
              }) else { throw LoginError.invalidResponse }

        // 서버 발급 원문을 그대로 사용한다. nonce와 인가 코드는 매 시도 새로 발급한다.
        let credential = try await appleLogin(response.nonce)
        try Task.checkCancellation()
        guard !credential.identityToken.isEmpty, !credential.authorizationCode.isEmpty else {
            throw LoginError.invalidResponse
        }
        let request = APIRequest(
            path: ["api", "v1", "auth", "apple", "login"], method: .post,
            jsonBody: try JSONEncoder().encode(AppleLoginRequest(
                identityToken: credential.identityToken,
                authorizationCode: credential.authorizationCode,
                nonce: response.nonce, fullName: credential.fullName
            ))
        )
        let loginResponse = try await client.send(request, as: LoginResponse.self)
        try saveSession(loginResponse)
    }

    private func saveSession(_ response: LoginResponse) throws {
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
