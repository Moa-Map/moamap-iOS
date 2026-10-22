import Foundation

nonisolated struct TermResponse: Decodable, Sendable {
    let termId: Int64
    let code: String?
    let title: String?
    let version: String?
    let kind: String?

    func toDomain() -> Term {
        Term(
            id: termId,
            code: code ?? "",
            title: title ?? "",
            version: version ?? "",
            kind: kind == "REQUIRED" ? .required : .viewOnly
        )
    }
}

nonisolated struct TermDetailResponse: Decodable, Sendable {
    let termId: Int64
    let code: String?
    let title: String?
    let version: String?
    let kind: String?
    let active: Bool?
    let content: String?

    func toDomain() -> TermDetail {
        TermDetail(
            term: TermResponse(termId: termId, code: code, title: title, version: version, kind: kind).toDomain(),
            isActive: active ?? true,
            content: content ?? ""
        )
    }
}

nonisolated struct TermAgreementStatusResponse: Decodable, Sendable {
    let needsAgreement: Bool
    let pendingTerms: [TermResponse]?

    func toDomain() -> TermAgreementStatus {
        TermAgreementStatus(needsAgreement: needsAgreement, pendingTerms: (pendingTerms ?? []).map { $0.toDomain() })
    }
}

nonisolated struct AgreeTermsRequest: Encodable, Sendable {
    let termIds: [Int64]
}
