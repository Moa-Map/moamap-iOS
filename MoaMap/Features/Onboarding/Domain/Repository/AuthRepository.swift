@MainActor
protocol AuthRepository {
    func loginWithKakao() async throws
    func loginWithApple() async throws
    /// 서버·카카오 로그아웃 실패와 무관하게 로컬 세션을 지운다.
    func logout() async throws
    func hasSession() throws -> Bool
}
