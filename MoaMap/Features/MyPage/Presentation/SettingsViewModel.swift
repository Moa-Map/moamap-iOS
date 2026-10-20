import Foundation
import Observation

nonisolated enum SettingsUiState: Equatable, Sendable {
    case idle
    case loggingOut
    case loggedOut
    case withdrawing
    case withdrawn
    case failed(title: String, message: String)

    /// 진행 중이거나 끝나 로그인 화면으로 가는 중이면 새 요청을 받지 않는다.
    var isBusy: Bool {
        switch self {
        case .loggingOut, .loggedOut, .withdrawing, .withdrawn: true
        case .idle, .failed: false
        }
    }
}

@MainActor @Observable
final class SettingsViewModel {
    private(set) var uiState: SettingsUiState = .idle
    private(set) var loadTask: Task<Void, Never>?
    private let repository: any AuthRepository

    init(repository: any AuthRepository) { self.repository = repository }

    func logout(onLoggedOut: @escaping () -> Void = {}) {
        run(
            { try await $0.logout() }, inProgress: .loggingOut, done: .loggedOut,
            failure: .failed(title: "로그아웃할 수 없습니다", message: "로그아웃하지 못했어요. 잠시 후 다시 시도해 주세요."),
            completion: onLoggedOut
        )
    }

    func withdraw(onWithdrawn: @escaping () -> Void = {}) {
        run(
            { try await $0.withdraw() }, inProgress: .withdrawing, done: .withdrawn,
            failure: .failed(title: "탈퇴할 수 없습니다", message: "탈퇴하지 못했어요. 잠시 후 다시 시도해 주세요."),
            completion: onWithdrawn
        )
    }

    func dismissError() {
        if case .failed = uiState { uiState = .idle }
    }

    private func run(
        _ work: @escaping (any AuthRepository) async throws -> Void,
        inProgress: SettingsUiState, done: SettingsUiState, failure: SettingsUiState,
        completion: @escaping () -> Void
    ) {
        guard !uiState.isBusy else { return }
        loadTask?.cancel()
        uiState = inProgress
        loadTask = Task { [weak self, repository] in
            do {
                try await work(repository)
                try Task.checkCancellation()
                self?.uiState = done
                // 화면과 ViewModel이 해제되어도 Task가 보관한 완료 콜백은 실행한다.
                completion()
            } catch is CancellationError {
                if !Task.isCancelled { self?.uiState = .idle }
            } catch {
                // 로컬 세션이 남았을 수 있어 로그인 화면으로 보내지 않는다.
                guard !Task.isCancelled else { return }
                self?.uiState = failure
            }
        }
    }
}
