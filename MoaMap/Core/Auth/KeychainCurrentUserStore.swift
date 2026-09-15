import Foundation

nonisolated struct KeychainCurrentUserStore: CurrentUserStore {
    private let item: KeychainItem

    init(service: String) {
        item = KeychainItem(service: service, account: "current-user")
    }

    func load() throws -> Int64? {
        guard let data = try item.load(), let userId = try? JSONDecoder().decode(Int64.self, from: data), userId > 0 else { return nil }
        return userId
    }

    func save(userId: Int64) throws {
        guard userId > 0 else { return }
        try item.save(JSONEncoder().encode(userId))
    }

    func clear() throws { try item.clear() }
}
