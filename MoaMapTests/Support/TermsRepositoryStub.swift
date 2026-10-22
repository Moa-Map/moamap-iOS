import Foundation
@testable import MoaMap

@MainActor
final class TermsRepositoryStub: TermsRepository {
    nonisolated static let service = Term(id: 1, code: "SERVICE", title: "서비스 이용약관", version: "1.0", kind: .required)
    nonisolated static let age = Term(id: 2, code: "AGE", title: "만 14세 이상 확인", version: "1.0", kind: .required)
    nonisolated static let policy = Term(id: 3, code: "POLICY", title: "개인정보 처리방침", version: "1.0", kind: .viewOnly)

    var terms: () async throws -> [Term] = { [service, age, policy] }
    var detail: (Int64) async throws -> TermDetail = { id in
        TermDetail(term: TermsRepositoryStub.service, isActive: true, content: "# 약관 \(id)")
    }
    var status: () async throws -> TermAgreementStatus = {
        TermAgreementStatus(needsAgreement: true, pendingTerms: [service, age])
    }
    var agreeHandler: ([Int64]) async throws -> TermAgreementStatus = { _ in
        TermAgreementStatus(needsAgreement: false, pendingTerms: [])
    }
    private(set) var statusCalls = 0
    private(set) var agreements: [[Int64]] = []

    func fetchTerms() async throws -> [Term] { try await terms() }
    func fetchTerm(id: Int64) async throws -> TermDetail { try await detail(id) }

    func fetchAgreementStatus() async throws -> TermAgreementStatus {
        statusCalls += 1
        return try await status()
    }

    func agree(termIDs: [Int64]) async throws -> TermAgreementStatus {
        agreements.append(termIDs)
        return try await agreeHandler(termIDs)
    }
}
