import Foundation

nonisolated struct KeychainAuthTokenStore: AuthTokenStore {
    private let item: KeychainItem

    init(service: String) {
        item = KeychainItem(service: service, account: "auth-token")
    }

    func load() throws -> AuthToken? {
        guard let data = try item.load() else { return nil }
        guard let token = try? JSONDecoder().decode(AuthToken.self, from: data), token.isValid else { return nil }
        return token
    }

    func save(_ token: AuthToken) throws {
        // 두 토큰을 한 항목으로 갱신해 서로 다른 세대의 토큰이 섞이지 않게 한다.
        try item.save(JSONEncoder().encode(token))
    }

    func clear() throws { try item.clear() }
}
