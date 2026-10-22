import Foundation
import Observation

nonisolated enum SettingsUiState: Equatable, Sendable {
    case idle
    case loggingOut
    case loggedOut
    case withdrawing
    case withdrawn
    case loadingTerm
    case failed(title: String, message: String)

    /// 진행 중이거나 끝나 로그인 화면으로 가는 중이면 새 요청을 받지 않는다.
    var isBusy: Bool {
        switch self {
        case .loggingOut, .loggedOut, .withdrawing, .withdrawn, .loadingTerm: true
        case .idle, .failed: false
        }
    }
}

@MainActor @Observable
final class SettingsViewModel {
    private(set) var uiState: SettingsUiState = .idle
    private(set) var loadTask: Task<Void, Never>?
    private let repository: any AuthRepository
    private let termsRepository: any TermsRepository

    init(repository: any AuthRepository, termsRepository: any TermsRepository) {
        self.repository = repository
        self.termsRepository = termsRepository
    }

    /// 약관 목록에서 `code` 인 약관을 찾아 `onFound` 로 넘긴다.
    func openTerm(code: String, onFound: @escaping (Term) -> Void) {
        guard !uiState.isBusy else { return }
        loadTask?.cancel()
        uiState = .loadingTerm
        let failure = SettingsUiState.failed(title: "약관을 열 수 없습니다", message: "약관을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.")
        loadTask = Task { [weak self, termsRepository] in
            do {
                let terms = try await termsRepository.fetchTerms()
                try Task.checkCancellation()
                // 설정을 떠났으면 열지 않는다.
                guard let self else { return }
                if let term = terms.first(where: { $0.code == code }) {
                    uiState = .idle
                    onFound(term)
                } else {
                    uiState = failure
                }
            } catch is CancellationError {
                if !Task.isCancelled { self?.uiState = .idle }
            } catch {
                guard !Task.isCancelled else { return }
                self?.uiState = failure
            }
        }
    }

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

    /// 약관을 찾는 중이면 그만둔다. 로그아웃·탈퇴는 화면을 떠나도 끝까지 간다.
    func cancelTermLoading() {
        guard uiState == .loadingTerm else { return }
        loadTask?.cancel()
        loadTask = nil
        uiState = .idle
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
