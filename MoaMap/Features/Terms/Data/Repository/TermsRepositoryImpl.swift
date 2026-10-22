import Foundation

@MainActor
final class TermsRepositoryImpl: TermsRepository {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    func fetchTerms() async throws -> [Term] {
        let request = APIRequest(path: ["api", "v1", "terms"])
        return try await client.send(request, as: [TermResponse].self).map { $0.toDomain() }
    }

    func fetchTerm(id: Int64) async throws -> TermDetail {
        let request = APIRequest(path: ["api", "v1", "terms", String(id)])
        return try await client.send(request, as: TermDetailResponse.self).toDomain()
    }

    func fetchAgreementStatus() async throws -> TermAgreementStatus {
        let request = APIRequest(path: ["api", "v1", "terms", "agreements", "me"])
        return try await client.send(request, as: TermAgreementStatusResponse.self).toDomain()
    }

    func agree(termIDs: [Int64]) async throws -> TermAgreementStatus {
        let request = APIRequest(
            path: ["api", "v1", "terms", "agreements"],
            method: .post,
            jsonBody: try JSONEncoder().encode(AgreeTermsRequest(termIds: termIDs))
        )
        return try await client.send(request, as: TermAgreementStatusResponse.self).toDomain()
    }
}
