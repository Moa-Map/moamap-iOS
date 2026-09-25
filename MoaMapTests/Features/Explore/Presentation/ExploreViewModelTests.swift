import Foundation
import Testing
@testable import MoaMap

@MainActor
final class ExploreRepositoryStub: ExploreRepository {
    var recommended: () async throws -> [MapSummary] = { [] }
    var community: (MapSortOrder, Int) async throws -> MapPage = { _, _ in MapPage(maps: [], isLast: true) }
    var nickname: () async throws -> String? = { nil }
    private(set) var communityCalls: [(MapSortOrder, Int)] = []

    func fetchRecommendedMaps(size: Int) async throws -> [MapSummary] { try await recommended() }
    func fetchCommunityMaps(sort: MapSortOrder, page: Int, size: Int) async throws -> MapPage {
        communityCalls.append((sort, page))
        return try await community(sort, page)
    }
    func fetchMyNickname() async throws -> String? { try await nickname() }
}

private func map(_ id: Int64) -> MapSummary {
    MapSummary(id: id, title: "지도 \(id)", imageURL: nil, tags: [], memberCount: 0, placeCount: 0)
}

@MainActor
struct ExploreViewModelTests {
    @Test func 처음_불러오면_추천_커뮤니티_닉네임을_반영한다() async {
        let repository = ExploreRepositoryStub()
        repository.recommended = { [map(1)] }
        repository.community = { _, _ in MapPage(maps: [map(2), map(3)], isLast: true) }
        repository.nickname = { "모아" }
        let sut = ExploreViewModel(repository: repository)
        sut.loadIfNeeded()
        #expect(sut.uiState == .loading)
        await sut.loadTask?.value
        #expect(sut.uiState == .loaded)
        #expect(sut.recommendedMaps == [map(1)])
        #expect(sut.communityMaps == [map(2), map(3)])
        #expect(sut.nickname == "모아")
        #expect(repository.communityCalls.map(\.1) == [0])
    }

    @Test func 이미_불러왔으면_다시_요청하지_않는다() async {
        let repository = ExploreRepositoryStub()
        let sut = ExploreViewModel(repository: repository)
        sut.loadIfNeeded()
        await sut.loadTask?.value
        sut.loadIfNeeded()
        await sut.loadTask?.value
        #expect(repository.communityCalls.count == 1)
    }

    @Test func 닉네임_실패는_화면을_막지_않는다() async {
        let repository = ExploreRepositoryStub()
        repository.nickname = { throw NetworkError.http(statusCode: 500) }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState == .loaded)
        #expect(sut.nickname == nil)
    }

    @Test func 목록_실패시_서버_원문_없이_오류를_보여주고_재시도한다() async {
        let repository = ExploreRepositoryStub()
        repository.recommended = { throw NetworkError.server(code: "MAP_500", statusCode: 500) }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        await sut.loadTask?.value
        guard case .failed(let message) = sut.uiState else { Issue.record("오류 상태가 필요하다"); return }
        #expect(!message.contains("MAP_500"))
        repository.recommended = { [map(1)] }
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState == .loaded)
        #expect(sut.recommendedMaps == [map(1)])
    }

    @Test func 마지막_카드가_보이면_다음_페이지를_이어붙이고_마지막에서_멈춘다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, page in
            page == 0 ? MapPage(maps: [map(1), map(2)], isLast: false) : MapPage(maps: [map(2), map(3)], isLast: true)
        }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        await sut.loadTask?.value

        sut.loadMoreIfNeeded(after: map(1))
        #expect(sut.pageTask == nil)

        sut.loadMoreIfNeeded(after: map(2))
        #expect(sut.isLoadingMore)
        await sut.pageTask?.value
        #expect(sut.communityMaps == [map(1), map(2), map(3)])
        #expect(!sut.isLoadingMore)

        sut.loadMoreIfNeeded(after: map(3))
        #expect(sut.pageTask == nil)
        #expect(repository.communityCalls.map(\.1) == [0, 1])
    }

    @Test func 다음_페이지_실패는_기존_목록을_유지한다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, page in
            if page > 0 { throw NetworkError.connection(.notConnectedToInternet) }
            return MapPage(maps: [map(1)], isLast: false)
        }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        await sut.loadTask?.value
        sut.loadMoreIfNeeded(after: map(1))
        await sut.pageTask?.value
        #expect(sut.uiState == .loaded)
        #expect(sut.communityMaps == [map(1)])
        #expect(!sut.isLoadingMore)
    }

    @Test func 정렬을_바꾸면_첫_페이지부터_다시_불러온다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { sort, _ in
            MapPage(maps: sort == .popular ? [map(1)] : [map(9)], isLast: false)
        }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        await sut.loadTask?.value
        sut.changeSort(.latest)
        #expect(sut.sortOrder == .latest)
        await sut.pageTask?.value
        #expect(sut.communityMaps == [map(9)])
        #expect(repository.communityCalls.map(\.0) == [.popular, .latest])
        #expect(repository.communityCalls.map(\.1) == [0, 0])

        sut.changeSort(.latest)
        #expect(repository.communityCalls.count == 2)
    }

    @Test func 정렬_변경은_진행중인_이전_페이지_결과를_버린다() async {
        let repository = ExploreRepositoryStub()
        let started = AsyncGate()
        let release = AsyncGate()
        repository.community = { sort, page in
            if page == 1 {
                await started.open()
                await release.wait()
                return MapPage(maps: [map(2)], isLast: true)
            }
            return MapPage(maps: sort == .popular ? [map(1)] : [map(9)], isLast: false)
        }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        await sut.loadTask?.value
        sut.loadMoreIfNeeded(after: map(1))
        let old = sut.pageTask
        await started.wait()
        sut.changeSort(.latest)
        await sut.pageTask?.value
        await release.open()
        await old?.value
        #expect(sut.communityMaps == [map(9)])
    }
}
