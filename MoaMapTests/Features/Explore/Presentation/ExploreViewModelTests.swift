import Foundation
import Testing
@testable import MoaMap

private func map(_ id: Int64) -> MapSummary {
    MapSummary(id: id, title: "지도 \(id)", imageURL: nil, tags: [], memberCount: 0, placeCount: 0)
}

private func official(_ id: Int64) -> OfficialMap {
    OfficialMap(id: id, title: "공식 \(id)", description: "", imageURL: nil, joined: false)
}

@MainActor
private func makeSUT(
    _ repository: ExploreRepositoryStub = ExploreRepositoryStub(),
    _ officialRepository: OfficialMapRepositoryStub = OfficialMapRepositoryStub()
) -> ExploreViewModel {
    ExploreViewModel(repository: repository, officialMapRepository: officialRepository)
}

@MainActor
private func settle(_ sut: ExploreViewModel) async {
    await sut.loadTask?.value
    await sut.officialTask?.value
}

@MainActor
struct ExploreViewModelTests {
    @Test func 처음_불러오면_인기순_커뮤니티_3개와_공식지도를_반영한다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in MapPage(maps: [map(2), map(3)], isLast: true) }
        let officialRepository = OfficialMapRepositoryStub()
        officialRepository.fetch = { [official(1)] }
        let sut = makeSUT(repository, officialRepository)
        sut.refresh()
        #expect(sut.uiState == .loading)
        #expect(sut.officialState == .loading)
        await settle(sut)
        #expect(sut.uiState == .loaded)
        #expect(sut.communityMaps == [map(2), map(3)])
        #expect(sut.officialState == .loaded([official(1)]))
        #expect(repository.communityRequests == [.init(tag: nil, sort: .popular, page: 0, size: 3)])
        #expect(repository.recommendationCalls == 0)
        #expect(repository.nicknameCalls == 0)
    }

    @Test func 공식지도는_앞_5개만_보여준다() async {
        let officialRepository = OfficialMapRepositoryStub()
        officialRepository.fetch = { (1...7).map(official) }
        let sut = makeSUT(ExploreRepositoryStub(), officialRepository)
        sut.refresh()
        await settle(sut)
        #expect(sut.officialState == .loaded((1...5).map(official)))
    }

    @Test func 처음_읽는_중에_다시_보여도_또_요청하지_않는다() async {
        let repository = ExploreRepositoryStub()
        let officialRepository = OfficialMapRepositoryStub()
        let sut = makeSUT(repository, officialRepository)
        sut.refresh()
        sut.refresh()
        await settle(sut)
        #expect(repository.communityCalls.count == 1)
        #expect(officialRepository.fetchCalls == 1)
    }

    @Test func 돌아오면_보던_목록을_둔_채_다시_읽는다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in MapPage(maps: [map(1), map(2)], isLast: true) }
        let officialRepository = OfficialMapRepositoryStub()
        officialRepository.fetch = { [official(1)] }
        let sut = makeSUT(repository, officialRepository)
        sut.refresh()
        await settle(sut)

        repository.community = { _, _ in MapPage(maps: [map(2)], isLast: true) }
        officialRepository.fetch = { [official(1), official(2)] }
        sut.refresh()
        #expect(sut.uiState == .loaded)
        #expect(sut.communityMaps == [map(1), map(2)])
        #expect(sut.officialState == .loaded([official(1)]))
        await settle(sut)
        #expect(sut.communityMaps == [map(2)])
        #expect(sut.officialState == .loaded([official(1), official(2)]))
        #expect(repository.communityCalls.count == 2)
        #expect(officialRepository.fetchCalls == 2)
    }

    @Test func 돌아와서_다시_읽기가_실패해도_보던_목록을_지우지_않는다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in MapPage(maps: [map(1)], isLast: true) }
        let officialRepository = OfficialMapRepositoryStub()
        officialRepository.fetch = { [official(1)] }
        let sut = makeSUT(repository, officialRepository)
        sut.refresh()
        await settle(sut)

        repository.community = { _, _ in throw NetworkError.http(statusCode: 500) }
        officialRepository.fetch = { throw NetworkError.http(statusCode: 500) }
        sut.refresh()
        await settle(sut)
        #expect(sut.uiState == .loaded)
        #expect(sut.communityMaps == [map(1)])
        #expect(sut.officialState == .loaded([official(1)]))
    }

    @Test func 실패한_채로_돌아오면_다시_시도한다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in throw NetworkError.http(statusCode: 500) }
        let sut = makeSUT(repository)
        sut.refresh()
        await settle(sut)
        guard case .failed = sut.uiState else { Issue.record("오류 상태가 필요하다"); return }

        repository.community = { _, _ in MapPage(maps: [map(1)], isLast: true) }
        sut.refresh()
        #expect(sut.uiState == .loading)
        await settle(sut)
        #expect(sut.communityMaps == [map(1)])
    }

    @Test func 목록_실패시_서버_원문_없이_오류를_보여주고_재시도한다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in throw NetworkError.server(code: "MAP_500", statusCode: 500) }
        let officialRepository = OfficialMapRepositoryStub()
        officialRepository.fetch = { [official(1)] }
        let sut = makeSUT(repository, officialRepository)
        sut.load()
        await settle(sut)
        guard case .failed(let message) = sut.uiState else { Issue.record("오류 상태가 필요하다"); return }
        #expect(!message.contains("MAP_500"))
        #expect(sut.officialState == .loaded([official(1)]))

        repository.community = { _, _ in MapPage(maps: [map(2)], isLast: true) }
        sut.retryCommunity()
        await settle(sut)
        #expect(sut.uiState == .loaded)
        #expect(sut.communityMaps == [map(2)])
        #expect(officialRepository.fetchCalls == 1)
    }

    @Test func 공식지도_실패는_커뮤니티를_막지_않고_따로_재시도한다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in MapPage(maps: [map(1)], isLast: true) }
        let officialRepository = OfficialMapRepositoryStub()
        officialRepository.fetch = { throw NetworkError.http(statusCode: 500) }
        let sut = makeSUT(repository, officialRepository)
        sut.load()
        await settle(sut)
        #expect(sut.uiState == .loaded)
        #expect(sut.officialState == .failed(OfficialMapListViewModel.loadFailedMessage))

        officialRepository.fetch = { [official(1)] }
        sut.retryOfficial()
        #expect(sut.officialState == .loading)
        await settle(sut)
        #expect(sut.officialState == .loaded([official(1)]))
        #expect(repository.communityCalls.count == 1)
    }

    @Test func 공식지도가_지연되어도_커뮤니티는_먼저_표시한다() async {
        let officialRepository = OfficialMapRepositoryStub()
        let release = AsyncGate()
        officialRepository.fetch = { await release.wait(); return [official(1)] }
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in MapPage(maps: [map(1)], isLast: true) }
        let sut = makeSUT(repository, officialRepository)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState == .loaded)
        #expect(sut.officialState == .loading)
        await release.open()
        await sut.officialTask?.value
        #expect(sut.officialState == .loaded([official(1)]))
    }

    @Test func 공식지도를_처음_읽는_중에_다시_보여도_요청을_끊지_않는다() async {
        let officialRepository = OfficialMapRepositoryStub()
        let release = AsyncGate()
        officialRepository.fetch = { await release.wait(); return [official(1)] }
        let sut = makeSUT(ExploreRepositoryStub(), officialRepository)
        sut.refresh()
        await sut.loadTask?.value
        let first = sut.officialTask
        sut.refresh()
        #expect(sut.officialTask == first)
        #expect(officialRepository.fetchCalls == 1)
        await release.open()
        await sut.officialTask?.value
        #expect(sut.officialState == .loaded([official(1)]))
    }

    @Test func 취소된_공식지도_요청은_새_결과를_덮지_않는다() async {
        let officialRepository = OfficialMapRepositoryStub()
        let started = AsyncGate()
        let release = AsyncGate()
        officialRepository.fetch = {
            await started.open()
            await release.wait()
            return [official(1)]
        }
        let sut = makeSUT(ExploreRepositoryStub(), officialRepository)
        sut.load()
        let old = sut.officialTask
        await started.wait()
        officialRepository.fetch = { [official(2)] }
        sut.load()
        await settle(sut)
        await release.open()
        await old?.value
        #expect(sut.officialState == .loaded([official(2)]))
    }
}
