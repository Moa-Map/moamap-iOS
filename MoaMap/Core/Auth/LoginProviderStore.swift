nonisolated enum LoginProvider: String, Codable, Sendable {
    case kakao, apple, google
}

/// 지금 세션을 연 로그인 수단. 탈퇴할 때 끊을 외부 연결을 고른다.
nonisolated protocol LoginProviderStore: Sendable {
    func load() throws -> LoginProvider?
    func save(_ provider: LoginProvider) throws
    func clear() throws
}
