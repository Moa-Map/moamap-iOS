@MainActor
protocol AuthRepository {
    func loginWithKakao() async throws
    func hasSession() throws -> Bool
}
