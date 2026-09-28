import Foundation
import Observation

nonisolated enum SettingsUiState: Equatable, Sendable {
    case idle
    case loggingOut
    case loggedOut
    case failed(String)
}

@MainActor @Observable
final class SettingsViewModel {
    private(set) var uiState: SettingsUiState = .idle
    private(set) var loadTask: Task<Void, Never>?
    private let repository: any AuthRepository

    init(repository: any AuthRepository) { self.repository = repository }

    func logout() {
        guard uiState != .loggingOut, uiState != .loggedOut else { return }
        loadTask?.cancel()
        uiState = .loggingOut
        loadTask = Task { [weak self, repository] in
            do {
                try await repository.logout()
                try Task.checkCancellation()
                self?.uiState = .loggedOut
            } catch is CancellationError {
                if !Task.isCancelled { self?.uiState = .idle }
            } catch {
                // 로컬 세션이 남았을 수 있어 로그인 화면으로 보내지 않는다.
                guard !Task.isCancelled else { return }
                self?.uiState = .failed("로그아웃하지 못했어요. 잠시 후 다시 시도해 주세요.")
            }
        }
    }

    func dismissError() {
        if case .failed = uiState { uiState = .idle }
    }
}
