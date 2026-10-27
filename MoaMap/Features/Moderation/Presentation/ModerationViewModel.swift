import Foundation
import Observation

/// 화면에 띄울 확인 팝업.
nonisolated enum ModerationPrompt: Equatable, Sendable {
    case report(ReportTarget, title: String)
    case block(userID: Int64, nickname: String?)
}

/// 한 화면의 신고·차단. 결과는 토스트로 알린다. 화면이 다른 일의 결과도 `notify` 로 같은 토스트에 띄운다.
@MainActor @Observable
final class ModerationViewModel {
    private(set) var prompt: ModerationPrompt?
    private(set) var submitting = false
    private(set) var toast: ToastMessage?
    private(set) var task: Task<Void, Never>?

    private let reportRepository: any ReportRepository
    private let blockedUsers: BlockedUserStore

    init(reportRepository: any ReportRepository, blockedUsers: BlockedUserStore) {
        self.reportRepository = reportRepository
        self.blockedUsers = blockedUsers
    }

    var blockedUserIDs: Set<Int64> { blockedUsers.ids }

    func askReport(_ target: ReportTarget, title: String) {
        guard !submitting else { return }
        prompt = .report(target, title: title)
    }

    func askBlock(userID: Int64, nickname: String?) {
        guard !submitting else { return }
        prompt = .block(userID: userID, nickname: nickname)
    }

    /// 보내는 동안에는 닫지 않는다. 결과 토스트가 엉뚱한 팝업 뒤에 뜬다.
    func dismiss() {
        guard !submitting else { return }
        prompt = nil
    }

    func report(reason: ReportReason, detail: String?) {
        guard case .report(let target, _) = prompt, !submitting else { return }
        run(failure: ModerationMessage.reportFailure) { [reportRepository] in
            try await reportRepository.report(target, reason: reason, detail: detail)
            return ToastMessage(text: ModerationMessage.reported)
        }
    }

    func confirmBlock() {
        guard case .block(let userID, let nickname) = prompt, !submitting else { return }
        run(failure: ModerationMessage.blockFailure) { [blockedUsers] in
            try await blockedUsers.block(userID: userID)
            return ToastMessage(text: ModerationMessage.blocked(nickname: nickname))
        }
    }

    func notify(_ message: ToastMessage) {
        toast = message
    }

    func consumeToast() {
        toast = nil
    }

    /// 실패해도 팝업은 닫는다. 이미 신고한 것처럼 다시 눌러도 같은 결과다.
    private func run(failure: @escaping (any Error) -> String, _ body: @escaping () async throws -> ToastMessage) {
        submitting = true
        task = Task { [weak self] in
            do {
                let message = try await body()
                try Task.checkCancellation()
                self?.finish(message)
            } catch {
                guard !(error is CancellationError) else { return }
                self?.finish(.failure(failure(error)))
            }
        }
    }

    private func finish(_ message: ToastMessage) {
        submitting = false
        prompt = nil
        toast = message
    }
}
