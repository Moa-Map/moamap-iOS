import Foundation

/// 카카오 로컬 API 를 앱에서 직접 부른다. 서버 프록시가 생기면 이 클래스만 갈아끼운다.
@MainActor
final class KakaoPlaceSearchRepository: PlaceSearchRepository {
    /// 카카오 기본값과 같다. 첫 페이지만 쓴다.
    private static let pageSize = 15

    private let client: APIClient
    private let restAPIKey: String

    init(client: APIClient, restAPIKey: String) {
        self.client = client
        self.restAPIKey = restAPIKey
    }

    func search(query: String) async throws -> [PlaceCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // 빈 검색어는 카카오가 400 을 낸다.
        guard !trimmed.isEmpty else { return [] }
        let request = APIRequest(
            path: ["v2", "local", "search", "keyword.json"],
            queryItems: [URLQueryItem(name: "query", value: trimmed), URLQueryItem(name: "size", value: String(Self.pageSize))],
            headers: ["Authorization": "KakaoAK \(restAPIKey)"]
        )
        let data = try await client.send(request)
        let response = try JSONDecoder().decode(KakaoKeywordSearchResponse.self, from: data)
        return (response.documents ?? []).compactMap { $0.toCandidate() }
    }
}
