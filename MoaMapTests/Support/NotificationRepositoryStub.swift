import Foundation
@testable import MoaMap

@MainActor
final class NotificationRepositoryStub: NotificationRepository {
    nonisolated static func notification(
        _ id: Int64, kind: NotificationKind = .placeApproved, read: Bool = false, mapID: Int64? = 10, targetID: Int64? = 20
    ) -> UserNotification {
        UserNotification(
            id: id, kind: kind, message: "알림 \(id)", targetID: targetID, mapID: mapID, read: read,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    var page: (Int, Int) async throws -> NotificationPage = { _, _ in
        NotificationPage(notifications: [NotificationRepositoryStub.notification(1)], isLast: true)
    }
    var read: (Int64) async throws -> Void = { _ in }
    var readAll: () async throws -> Void = {}
    private(set) var pageRequests: [(page: Int, size: Int)] = []
    private(set) var readIDs: [Int64] = []
    private(set) var readAllCount = 0

    func fetchNotifications(page: Int, size: Int) async throws -> NotificationPage {
        pageRequests.append((page, size))
        return try await self.page(page, size)
    }

    func markRead(id: Int64) async throws {
        readIDs.append(id)
        try await read(id)
    }

    func markAllRead() async throws {
        readAllCount += 1
        try await readAll()
    }
}
