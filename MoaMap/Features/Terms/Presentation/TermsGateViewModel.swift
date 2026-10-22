import Foundation
import Observation

/// 로그인 뒤 홈에 들어가기 전에 약관 동의 여부를 확인한다.
nonisolated enum TermsGateState: Equatable, Sendable {
    case idle
    case checking
    case needsAgreement
    case passed
    /// 세션이 비었다. 로그인 화면으로 돌려보낸다.
    case unauthorized
    /// 확인에 실패해 로그아웃으로 빠져나가는 중.
    case loggingOut
    case failed(String)

    var failureMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }
}

@MainActor @Observable
final class TermsGateViewModel {
    static let failureMessage = "약관 동의 여부를 확인하지 못했어요"
    static let logoutFailureMessage = "로그아웃하지 못했어요. 잠시 후 다시 시도해 주세요."

    private(set) var state: TermsGateState = .idle
    private(set) var loadTask: Task<Void, Never>?
    private let repository: any TermsRepository
    private let authRepository: any AuthRepository

    init(repository: any TermsRepository, authRepository: any AuthRepository) {
        self.repository = repository
        self.authRepository = authRepository
    }

    func check() {
        loadTask?.cancel()
        state = .checking
        loadTask = Task { [weak self, repository, authRepository] in
            do {
                let status = try await repository.fetchAgreementStatus()
                try Task.checkCancellation()
                self?.state = status.needsAgreement ? .needsAgreement : .passed
            } catch is CancellationError {
                // Task<Void, Never> 경계. 취소된 확인은 상태를 바꾸지 않는다.
            } catch {
                guard !Task.isCancelled else { return }
                // 갱신이 일시 장애로 끝난 401 은 세션이 남아 있다. 다시 시도하게 한다.
                let expired = Self.isUnauthorized(error) && (try? authRepository.hasSession()) == false
                self?.state = expired ? .unauthorized : .failed(Self.failureMessage)
            }
        }
    }

    /// 확인에 실패한 채 갇히지 않게 로그아웃한다. 로컬 세션을 지운 뒤 `onLoggedOut` 을 부른다.
    func logout(onLoggedOut: @escaping () -> Void) {
        guard case .failed = state else { return }
        loadTask?.cancel()
        state = .loggingOut
        loadTask = Task { [weak self, authRepository] in
            do {
                try await authRepository.logout()
                try Task.checkCancellation()
                onLoggedOut()
            } catch is CancellationError {
                // Task<Void, Never> 경계. 취소된 로그아웃은 상태를 바꾸지 않는다.
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .failed(Self.logoutFailureMessage)
            }
        }
    }

    func agreed() {
        loadTask?.cancel()
        state = .passed
    }

    func reset() {
        loadTask?.cancel()
        loadTask = nil
        state = .idle
    }

    private static func isUnauthorized(_ error: any Error) -> Bool {
        switch error as? NetworkError {
        case .http(401), .server(_, 401, _): true
        default: false
        }
    }
}
