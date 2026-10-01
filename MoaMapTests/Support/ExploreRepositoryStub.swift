import Foundation
@testable import MoaMap

@MainActor
final class ExploreRepositoryStub: ExploreRepository {
    var recommended: () async throws -> [MapSummary] = { [] }
    var community: (MapSortOrder, Int) async throws -> MapPage = { _, _ in MapPage(maps: [], isLast: true) }
    /// 태그까지 보는 테스트용. 지정하면 `community` 대신 쓴다.
    var communityByTag: ((String?, MapSortOrder, Int, Int) async throws -> MapPage)?
    var nickname: () async throws -> String? = { nil }
    private(set) var recommendationCalls = 0
    private(set) var nicknameCalls = 0
    private(set) var communityCalls: [(MapSortOrder, Int)] = []
    private(set) var communityRequests: [CommunityRequest] = []

    struct CommunityRequest: Equatable {
        let tag: String?
        let sort: MapSortOrder
        let page: Int
        let size: Int
    }

    func fetchRecommendedMaps(size: Int) async throws -> [MapSummary] {
        recommendationCalls += 1
        return try await recommended()
    }
    func fetchCommunityMaps(tag: String?, sort: MapSortOrder, page: Int, size: Int) async throws -> MapPage {
        communityCalls.append((sort, page))
        communityRequests.append(CommunityRequest(tag: tag, sort: sort, page: page, size: size))
        if let communityByTag { return try await communityByTag(tag, sort, page, size) }
        return try await community(sort, page)
    }
    func fetchMyNickname() async throws -> String? {
        nicknameCalls += 1
        return try await nickname()
    }
}
