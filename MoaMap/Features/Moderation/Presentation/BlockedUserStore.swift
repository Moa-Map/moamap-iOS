import Foundation
import Observation

/// 내가 차단한 사람. 앱 전체가 하나를 같이 보고, 차단하면 서버 응답을 기다리지 않고 화면에서 바로 거른다.
@MainActor @Observable
final class BlockedUserStore {
    private(set) var ids: Set<Int64> = []

    private let repository: any BlockRepository

    init(repository: any BlockRepository) { self.repository = repository }

    func block(userID: Int64) async throws {
        try await repository.block(userID: userID)
        ids.insert(userID)
    }
}
