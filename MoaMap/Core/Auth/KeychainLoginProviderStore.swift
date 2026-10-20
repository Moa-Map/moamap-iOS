import Foundation

nonisolated struct KeychainLoginProviderStore: LoginProviderStore {
    private let item: KeychainItem

    init(service: String) {
        item = KeychainItem(service: service, account: "login-provider")
    }

    func load() throws -> LoginProvider? {
        guard let data = try item.load() else { return nil }
        return try? JSONDecoder().decode(LoginProvider.self, from: data)
    }

    func save(_ provider: LoginProvider) throws {
        try item.save(JSONEncoder().encode(provider))
    }

    func clear() throws { try item.clear() }
}
