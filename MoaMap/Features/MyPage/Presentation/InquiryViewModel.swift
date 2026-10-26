import Foundation
import Observation

nonisolated struct InquiryUiState: Equatable, Sendable {
    var type: InquiryType?
    var email = ""
    var content = ""
    var submitting = false
    var errorMessage: String?
    /// 접수됐다. 화면이 접수 팝업을 띄우고, 닫으면 문의 화면을 나간다.
    var submitted = false

    var canSubmit: Bool { !submitting && InquiryForm.isComplete(type: type, email: email, content: content) }
}

/// 서버가 받는 길이와 형식. 넘으면 400 이라 입력에서 막는다.
nonisolated enum InquiryForm {
    static let emailMaxLength = 254
    static let contentMaxLength = 2000

    /// 공백 없이 `@` 앞뒤에 글자가 있고, `@` 뒤에 `.` 이 있다. 서버 정규식과 같다.
    static func isEmailShaped(_ email: String) -> Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).wholeMatch(of: /[^\s@]+@[^\s@]+\.[^\s@]+/) != nil
    }

    static func isComplete(type: InquiryType?, email: String, content: String) -> Bool {
        type != nil && isEmailShaped(email) && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// 답변 받을 이메일은 처음 열 때 내 계정 이메일로 한 번 채운다. 사용자가 먼저 적었거나 지웠으면 덮지 않는다.
@MainActor @Observable
final class InquiryViewModel {
    nonisolated static let sendFailedMessage = "문의를 보내지 못했어요"
    nonisolated static let offlineMessage = "네트워크에 연결할 수 없어요"

    private(set) var uiState = InquiryUiState()
    private(set) var prefillTask: Task<Void, Never>?
    private(set) var submitTask: Task<Void, Never>?

    private var emailTouched = false
    private let repository: any InquiryRepository
    private let userRepository: any UserRepository

    init(repository: any InquiryRepository, userRepository: any UserRepository) {
        self.repository = repository
        self.userRepository = userRepository
    }

    func prefillEmail() {
        guard prefillTask == nil, !emailTouched else { return }
        prefillTask = Task { [weak self, userRepository] in
            // 못 받아도 빈칸으로 두면 된다.
            guard let email = try? await userRepository.fetchMyProfile().email, !Task.isCancelled else { return }
            self?.applyPrefill(email)
        }
    }

    func selectType(_ type: InquiryType) { uiState.type = type }

    func updateEmail(_ email: String) {
        emailTouched = true
        uiState.email = String(email.prefix(InquiryForm.emailMaxLength))
    }

    func updateContent(_ content: String) {
        uiState.content = String(content.prefix(InquiryForm.contentMaxLength))
    }

    func submit() {
        guard uiState.canSubmit, let type = uiState.type else { return }
        let (email, content) = (uiState.email, uiState.content)
        // 작업이 시작되기 전에 잠근다. 두 번 눌러도 한 번만 간다.
        uiState.submitting = true
        uiState.errorMessage = nil
        submitTask = Task { [weak self, repository] in
            do {
                try await repository.sendInquiry(type: type, replyEmail: email, content: content)
                self?.uiState.submitting = false
                self?.uiState.submitted = true
            } catch {
                // 이메일·내용은 남기지 않는다.
                self?.uiState.submitting = false
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.errorMessage = Self.message(for: error)
            }
        }
    }

    func consumeError() { uiState.errorMessage = nil }

    private func applyPrefill(_ email: String) {
        guard !emailTouched, uiState.email.isEmpty else { return }
        emailTouched = true
        uiState.email = String(email.trimmingCharacters(in: .whitespacesAndNewlines).prefix(InquiryForm.emailMaxLength))
    }

    /// 하루 한도를 넘긴 것(429 `USER_013`)은 사용자가 알아야 할 서버 안내라 그대로 보여 준다.
    private nonisolated static func message(for error: any Error) -> String {
        guard let error = error as? NetworkError else { return sendFailedMessage }
        if case .connection = error { return offlineMessage }
        if case .server("USER_013", 429, _) = error, let message = error.serverMessage { return message }
        return sendFailedMessage
    }
}
