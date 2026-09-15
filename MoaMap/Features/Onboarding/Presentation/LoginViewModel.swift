import Foundation
import Observation

nonisolated enum LoginUiState: Equatable, Sendable {
    case idle
    case loading
    case authenticated
    case failed(String)
}

@MainActor @Observable
final class LoginViewModel {
    private(set) var uiState: LoginUiState = .idle
    private(set) var loadTask: Task<Void, Never>?
    private let repository: any AuthRepository

    init(repository: any AuthRepository) { self.repository = repository }

    func loginWithKakao() {
        guard uiState != .loading, uiState != .authenticated else { return }
        loadTask?.cancel()
        uiState = .loading
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                try await repository.loginWithKakao()
                try Task.checkCancellation()
                self?.uiState = .authenticated
            } catch is CancellationError {
                // Task<Void, Never> 경계. 취소된 요청은 UI를 갱신하지 않는다.
                if !Task.isCancelled { self?.uiState = .idle }
            } catch {
                guard !Task.isCancelled else { return }
                if error as? LoginError == .cancelled {
                    self?.uiState = .idle
                } else if let networkError = error as? NetworkError {
                    self?.uiState = .failed(networkError.userMessage)
                } else {
                    self?.uiState = .failed("카카오 로그인에 실패했어요. 다시 시도해 주세요.")
                }
            }
        }
    }

    func restoreSession() {
        guard uiState == .idle, loadTask == nil else { return }
        do {
            if try repository.hasSession() { uiState = .authenticated }
        } catch {
            uiState = .failed("로그인 정보를 확인하지 못했어요. 다시 시도해 주세요.")
        }
    }

    func dismissError() {
        if case .failed = uiState { uiState = .idle }
    }

    func cancelLogin() {
        loadTask?.cancel()
        loadTask = nil
        if uiState == .loading { uiState = .idle }
    }

    func sessionExpired() {
        cancelLogin()
        uiState = .idle
    }
}
