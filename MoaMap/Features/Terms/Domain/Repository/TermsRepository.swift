@MainActor
protocol TermsRepository {
    /// 지금 보여 줄 약관. 화면 순서대로다.
    func fetchTerms() async throws -> [Term]
    func fetchTerm(id: Int64) async throws -> TermDetail
    func fetchAgreementStatus() async throws -> TermAgreementStatus
    func agree(termIDs: [Int64]) async throws -> TermAgreementStatus
}
