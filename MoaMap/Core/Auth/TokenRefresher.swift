nonisolated enum TokenRefreshResult: Equatable, Sendable {
    case success(AuthToken)
    case rejected
    case failed
}

nonisolated protocol TokenRefresher: Sendable {
    func refresh(refreshToken: String) async throws -> TokenRefreshResult
}
