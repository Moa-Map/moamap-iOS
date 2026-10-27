import Foundation
import Observation
import SwiftUI

/// 내가 차단한 사람. 앱 전체가 하나를 같이 보고, 차단하면 서버 응답을 기다리지 않고 화면에서 바로 거른다.
/// 서버도 목록에서 걸러 주지만, 차단 직후 받아 둔 목록과 서버가 거르지 못한 응답을 여기서 한 번 더 거른다.
@MainActor @Observable
final class BlockedUserStore {
    private(set) var ids: Set<Int64> = []

    private let repository: any BlockRepository
    /// 차단·해제·비우기마다 늘린다. 그 사이에 늦게 온 목록은 `ids` 에 반영하지 않는다.
    private var revision = 0

    init(repository: any BlockRepository) { self.repository = repository }

    /// 서버 목록으로 맞추고 그 목록을 돌려준다.
    @discardableResult
    func reload() async throws -> [BlockedUser] {
        let started = revision
        let users = try await repository.fetchBlockedUsers()
        try Task.checkCancellation()
        if revision == started { ids = Set(users.map(\.id)) }
        return users
    }

    func block(userID: Int64) async throws {
        try await repository.block(userID: userID)
        revision += 1
        ids.insert(userID)
    }

    func unblock(userID: Int64) async throws {
        try await repository.unblock(userID: userID)
        revision += 1
        ids.remove(userID)
    }

    /// 로그아웃하면 비운다. 다음 계정에 앞 사람의 차단이 남지 않게 한다.
    func clear() {
        revision += 1
        ids = []
    }
}

extension EnvironmentValues {
    /// 화면이 걸러 낼 작성자. 앱 맨 위에서 `BlockedUserStore.ids` 를 내려준다.
    @Entry var blockedUserIDs: Set<Int64> = []
}
