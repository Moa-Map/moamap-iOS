import Foundation
@testable import MoaMap

@MainActor
final class ReportRepositoryStub: ReportRepository {
    var report: (ReportTarget) async throws -> Void = { _ in }
    private(set) var sent: [(target: ReportTarget, reason: ReportReason, detail: String?)] = []

    func report(_ target: ReportTarget, reason: ReportReason, detail: String?) async throws {
        sent.append((target, reason, detail))
        try await report(target)
    }
}

@MainActor
final class BlockRepositoryStub: BlockRepository {
    var users: () async throws -> [BlockedUser] = { [] }
    var block: (Int64) async throws -> Void = { _ in }
    var unblock: (Int64) async throws -> Void = { _ in }
    private(set) var blocked: [Int64] = []
    private(set) var unblocked: [Int64] = []

    func fetchBlockedUsers() async throws -> [BlockedUser] { try await users() }

    func block(userID: Int64) async throws {
        blocked.append(userID)
        try await block(userID)
    }

    func unblock(userID: Int64) async throws {
        unblocked.append(userID)
        try await unblock(userID)
    }
}
