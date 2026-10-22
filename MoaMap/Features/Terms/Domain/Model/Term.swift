import Foundation

nonisolated enum TermKind: Equatable, Sendable {
    /// 동의해야 앱을 쓸 수 있다.
    case required
    /// 체크 없이 전문만 보여 준다.
    case viewOnly
}

nonisolated struct Term: Equatable, Hashable, Identifiable, Sendable {
    let id: Int64
    let code: String
    let title: String
    let version: String
    let kind: TermKind
}

nonisolated struct TermDetail: Equatable, Sendable {
    let term: Term
    let isActive: Bool
    /// Markdown 원문.
    let content: String
}

nonisolated struct TermAgreementStatus: Equatable, Sendable {
    let needsAgreement: Bool
    /// 아직 동의하지 않은 필수 약관. 개정 뒤면 바뀐 약관만 들어 있다.
    let pendingTerms: [Term]
}

nonisolated enum TermCode {
    static let service = "SERVICE"
    static let policy = "POLICY"
}

nonisolated enum TermsErrorCode {
    /// 화면을 그린 뒤 약관이 개정됐다.
    static let changed = "USER_023"
}
