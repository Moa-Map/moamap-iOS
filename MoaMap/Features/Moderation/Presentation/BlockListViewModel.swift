import Foundation
import Observation

nonisolated enum BlockListState: Equatable, Sendable {
    case loading
    case loaded([BlockedUser])
    case failed(String)
}

/// 설정 「차단 관리」. 해제는 확인 없이 바로 보내고, 되면 목록에서 뺀다.
@MainActor @Observable
final class BlockListViewModel {
    nonisolated static let loadFailedMessage = "차단한 사용자를 불러오지 못했어요"

    private(set) var state = BlockListState.loading
    /// 해제를 보내고 있는 사람. 그 줄의 버튼만 막는다.
    private(set) var unblockingIDs: Set<Int64> = []
    private(set) var toast: ToastMessage?
    private(set) var loadTask: Task<Void, Never>?
    private(set) var unblockTasks: [Int64: Task<Void, Never>] = [:]

    private let blockedUsers: BlockedUserStore

    init(blockedUsers: BlockedUserStore) { self.blockedUsers = blockedUsers }

    func load() {
        loadTask?.cancel()
        state = .loading
        loadTask = Task { [weak self, blockedUsers] in
            do {
                let users = try await blockedUsers.reload()
                try Task.checkCancellation()
                self?.state = .loaded(users)
            } catch {
                guard !(error is CancellationError) else { return }
                self?.state = .failed(MapDetailMessage.userMessage(for: error, fallback: Self.loadFailedMessage))
            }
        }
    }

    func unblock(userID: Int64) {
        guard case .loaded = state, !unblockingIDs.contains(userID) else { return }
        unblockingIDs.insert(userID)
        unblockTasks[userID] = Task { [weak self, blockedUsers] in
            do {
                try await blockedUsers.unblock(userID: userID)
                try Task.checkCancellation()
                guard let self else { return }
                if case .loaded(let users) = self.state { self.state = .loaded(users.filter { $0.id != userID }) }
                self.finishUnblock(userID)
            } catch {
                guard !(error is CancellationError), let self else { return }
                self.finishUnblock(userID)
                self.toast = .failure(ModerationMessage.unblockFailure(error))
            }
        }
    }

    func consumeToast() {
        toast = nil
    }

    private func finishUnblock(_ userID: Int64) {
        unblockingIDs.remove(userID)
        unblockTasks[userID] = nil
    }
}
