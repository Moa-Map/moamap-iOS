import Foundation
import Observation

nonisolated enum LoginProvider: Equatable, Sendable {
    case kakao, apple

    var displayName: String {
        switch self {
        case .kakao: "카카오"
        case .apple: "Apple"
        }
    }
}

nonisolated enum LoginUiState: Equatable, Sendable {
    case idle
    case loading(LoginProvider)
    case authenticated
    case failed(String)

    var loadingProvider: LoginProvider? {
        if case .loading(let provider) = self { return provider }
        return nil
    }
}

@MainActor @Observable
final class LoginViewModel {
    private(set) var uiState: LoginUiState = .idle
    private(set) var loadTask: Task<Void, Never>?
    private let repository: any AuthRepository

    init(repository: any AuthRepository) { self.repository = repository }

    func loginWithApple() {
        login(with: .apple)
    }

    func loginWithKakao() {
        login(with: .kakao)
    }

    private func login(with provider: LoginProvider) {
        guard uiState.loadingProvider == nil, uiState != .authenticated else { return }
        loadTask?.cancel()
        uiState = .loading(provider)
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                switch provider {
                case .kakao: try await repository.loginWithKakao()
                case .apple: try await repository.loginWithApple()
                }
                try Task.checkCancellation()
                self?.uiState = .authenticated
            } catch is CancellationError {
                // Task<Void, Never> 경계. 취소된 요청은 UI를 갱신하지 않는다.
                if !Task.isCancelled { self?.uiState = .idle }
            } catch {
                guard !Task.isCancelled else { return }
                if error as? LoginError == .cancelled {
                    self?.uiState = .idle
                } else {
                    self?.uiState = .failed(Self.errorMessage(error, provider: provider))
                }
            }
        }
    }

    private static func errorMessage(_ error: any Error, provider: LoginProvider) -> String {
        if let networkError = error as? NetworkError {
            if provider == .apple {
                switch networkError {
                case .http(401), .server(_, 401):
                    return "Apple 인증이 만료되었거나 유효하지 않아요. 다시 로그인해 주세요."
                case .http(503), .server(_, 503):
                    return "Apple 로그인을 일시적으로 사용할 수 없어요. 잠시 후 다시 시도해 주세요."
                default: break
                }
            }
            return networkError.userMessage
        }
        return "\(provider.displayName) 로그인에 실패했어요. 다시 시도해 주세요."
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
        if uiState.loadingProvider != nil { uiState = .idle }
    }

    func sessionExpired() {
        cancelLogin()
        uiState = .idle
    }
}
