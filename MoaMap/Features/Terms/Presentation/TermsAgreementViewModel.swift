import Foundation
import Observation

nonisolated enum TermsAgreementContent: Equatable, Sendable {
    case loading
    /// `pending` 은 체크할 약관, `viewOnly` 는 그 아래 「보기」 링크로 붙는 약관.
    case loaded(pending: [Term], viewOnly: [Term])
    case failed(String)
}

nonisolated struct TermsAgreementUiState: Equatable, Sendable {
    var content: TermsAgreementContent = .loading
    var checkedIDs: Set<Int64> = []
    var isSubmitting = false
    var isLeaving = false
    var notice: String?

    var pendingTerms: [Term] {
        if case .loaded(let pending, _) = content { return pending }
        return []
    }

    var allChecked: Bool { pendingTerms.allSatisfy { checkedIDs.contains($0.id) } }
}

@MainActor @Observable
final class TermsAgreementViewModel {
    static let loadFailureMessage = "약관을 불러오지 못했어요"
    static let changedMessage = "약관이 바뀌어 다시 확인해 주세요"
    static let submitFailureMessage = "동의하지 못했어요. 잠시 후 다시 시도해 주세요."
    static let logoutFailureMessage = "로그아웃하지 못했어요. 잠시 후 다시 시도해 주세요."

    private(set) var uiState = TermsAgreementUiState()
    private(set) var loadTask: Task<Void, Never>?
    private let repository: any TermsRepository
    private let authRepository: any AuthRepository

    init(repository: any TermsRepository, authRepository: any AuthRepository) {
        self.repository = repository
        self.authRepository = authRepository
    }

    func load() {
        loadTask?.cancel()
        uiState.content = .loading
        uiState.checkedIDs = []
        loadTask = Task { [weak self, repository] in
            do {
                let status = try await repository.fetchAgreementStatus()
                let terms = try await repository.fetchTerms()
                try Task.checkCancellation()
                self?.uiState.content = .loaded(
                    pending: status.pendingTerms, viewOnly: terms.filter { $0.kind == .viewOnly }
                )
            } catch is CancellationError {
                // Task<Void, Never> 경계. 취소된 요청은 화면을 바꾸지 않는다.
            } catch {
                guard !Task.isCancelled else { return }
                self?.uiState.content = .failed(Self.loadFailureMessage)
            }
        }
    }

    func toggle(_ term: Term) {
        if uiState.checkedIDs.remove(term.id) == nil { uiState.checkedIDs.insert(term.id) }
    }

    func toggleAll() {
        uiState.checkedIDs = uiState.allChecked ? [] : Set(uiState.pendingTerms.map(\.id))
    }

    func checkAll() {
        uiState.checkedIDs = Set(uiState.pendingTerms.map(\.id))
    }

    func dismissNotice() { uiState.notice = nil }

    /// 필수를 다 체크했을 때만 보낸다. 끝나면 `onAgreed` 를 부른다.
    func submit(onAgreed: @escaping () -> Void) {
        guard case .loaded(let pending, let viewOnly) = uiState.content, uiState.allChecked,
              !uiState.isSubmitting, !uiState.isLeaving else { return }
        // 그사이 다른 기기에서 동의를 마쳤다.
        guard !pending.isEmpty else { return onAgreed() }
        uiState.isSubmitting = true
        loadTask = Task { [weak self, repository] in
            do {
                let status = try await repository.agree(termIDs: pending.map(\.id))
                try Task.checkCancellation()
                self?.uiState.isSubmitting = false
                if status.needsAgreement {
                    // 보낸 사이 새 약관이 생겼다. 받은 목록으로 다시 그린다.
                    self?.reset(pending: status.pendingTerms, viewOnly: viewOnly, notice: Self.changedMessage)
                } else {
                    onAgreed()
                }
            } catch is CancellationError {
                if !Task.isCancelled { self?.uiState.isSubmitting = false }
            } catch NetworkError.server(code: TermsErrorCode.changed, statusCode: _, message: _) {
                guard !Task.isCancelled else { return }
                self?.reloadChanged(viewOnly: viewOnly)
            } catch {
                guard !Task.isCancelled else { return }
                self?.uiState.isSubmitting = false
                self?.uiState.notice = Self.submitFailureMessage
            }
        }
    }

    /// 로그인을 취소한다. 로컬 세션을 지운 뒤 `onLoggedOut` 을 부른다.
    func leave(onLoggedOut: @escaping () -> Void) {
        guard !uiState.isLeaving, !uiState.isSubmitting else { return }
        loadTask?.cancel()
        uiState.isLeaving = true
        loadTask = Task { [weak self, authRepository] in
            do {
                try await authRepository.logout()
                try Task.checkCancellation()
                onLoggedOut()
            } catch is CancellationError {
                if !Task.isCancelled { self?.uiState.isLeaving = false }
            } catch {
                guard !Task.isCancelled else { return }
                self?.uiState.isLeaving = false
                self?.uiState.notice = Self.logoutFailureMessage
            }
        }
    }

    private func reloadChanged(viewOnly: [Term]) {
        uiState.isSubmitting = false
        uiState.content = .loading
        uiState.checkedIDs = []
        uiState.notice = Self.changedMessage
        loadTask = Task { [weak self, repository] in
            do {
                let status = try await repository.fetchAgreementStatus()
                try Task.checkCancellation()
                self?.uiState.content = .loaded(pending: status.pendingTerms, viewOnly: viewOnly)
            } catch is CancellationError {
                // Task<Void, Never> 경계. 취소된 요청은 화면을 바꾸지 않는다.
            } catch {
                guard !Task.isCancelled else { return }
                self?.uiState.content = .failed(Self.loadFailureMessage)
            }
        }
    }

    private func reset(pending: [Term], viewOnly: [Term], notice: String) {
        uiState.content = .loaded(pending: pending, viewOnly: viewOnly)
        uiState.checkedIDs = []
        uiState.notice = notice
    }
}
