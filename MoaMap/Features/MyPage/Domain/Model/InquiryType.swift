/// 문의 유형. 화면 목록 순서대로다. 원시값이 곧 서버 값이라 바꾸면 서버가 400 으로 거절한다.
nonisolated enum InquiryType: String, CaseIterable, Sendable {
    case service = "SERVICE"
    case technical = "TECHNICAL"
    case account = "ACCOUNT"
    case report = "REPORT"
    case partnership = "PARTNERSHIP"
    case other = "OTHER"

    var label: String {
        switch self {
        case .service: "서비스 이용 문제"
        case .technical: "기술적 문제"
        case .account: "계정 관련"
        case .report: "신고 및 제재"
        case .partnership: "제휴 문의"
        case .other: "기타"
        }
    }
}
