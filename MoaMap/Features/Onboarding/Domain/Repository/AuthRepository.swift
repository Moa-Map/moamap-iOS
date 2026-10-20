@MainActor
protocol AuthRepository {
    func loginWithKakao() async throws
    func loginWithApple() async throws
    /// 서버·카카오 로그아웃 실패와 무관하게 로컬 세션을 지운다.
    func logout() async throws
    /// 중간에 실패하면 로컬 세션을 남겨 다시 시도하게 한다.
    func withdraw() async throws
    func hasSession() throws -> Bool
}
