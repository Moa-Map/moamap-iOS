@MainActor
protocol AuthRepository {
    func loginWithKakao() async throws
    func loginWithApple() async throws
    func hasSession() throws -> Bool
}
