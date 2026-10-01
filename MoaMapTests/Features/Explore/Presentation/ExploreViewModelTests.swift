import Foundation
import Testing
@testable import MoaMap

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
        sut.refresh()
        #expect(sut.uiState == .loading)
        await sut.loadTask?.value
        await sut.recommendationTask?.value
        await sut.nicknameTask?.value
        #expect(sut.uiState == .loaded)
        #expect(sut.recommendedMaps == [map(1)])
        #expect(sut.communityMaps == [map(2), map(3)])
        #expect(sut.nickname == "모아")
        #expect(repository.communityRequests == [.init(tag: nil, sort: .popular, page: 0, size: 5)])
    }

    @Test func 처음_읽는_중에_다시_보여도_또_요청하지_않는다() async {
        let repository = ExploreRepositoryStub()
        let sut = ExploreViewModel(repository: repository)
        sut.refresh()
        sut.refresh()
        await sut.loadTask?.value
        #expect(repository.communityCalls.count == 1)
    }

    @Test func 돌아오면_보던_목록을_둔_채_커뮤니티와_추천만_다시_읽는다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in MapPage(maps: [map(1), map(2)], isLast: true) }
        let sut = ExploreViewModel(repository: repository)
        sut.refresh()
        await sut.loadTask?.value
        await sut.recommendationTask?.value
        await sut.nicknameTask?.value

        // 참여한 지도는 서버가 목록에서 뺀다.
        repository.community = { _, _ in MapPage(maps: [map(2)], isLast: true) }
        sut.refresh()
        #expect(sut.uiState == .loaded)
        #expect(sut.communityMaps == [map(1), map(2)])
        await sut.loadTask?.value
        await sut.recommendationTask?.value
        #expect(sut.communityMaps == [map(2)])
        #expect(repository.communityCalls.count == 2)
        #expect(repository.recommendationCalls == 2)
        #expect(repository.nicknameCalls == 1)
    }

    @Test func 돌아와서_다시_읽기가_실패해도_보던_목록을_지우지_않는다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in MapPage(maps: [map(1)], isLast: true) }
        let sut = ExploreViewModel(repository: repository)
        sut.refresh()
        await sut.loadTask?.value

        repository.community = { _, _ in throw NetworkError.http(statusCode: 500) }
        sut.refresh()
        await sut.loadTask?.value
        #expect(sut.uiState == .loaded)
        #expect(sut.communityMaps == [map(1)])
    }

    @Test func 실패한_채로_돌아오면_다시_시도한다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in throw NetworkError.http(statusCode: 500) }
        let sut = ExploreViewModel(repository: repository)
        sut.refresh()
        await sut.loadTask?.value
        guard case .failed = sut.uiState else { Issue.record("오류 상태가 필요하다"); return }

        repository.community = { _, _ in MapPage(maps: [map(1)], isLast: true) }
        sut.refresh()
        #expect(sut.uiState == .loading)
        await sut.loadTask?.value
        #expect(sut.communityMaps == [map(1)])
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
        repository.community = { _, _ in throw NetworkError.server(code: "MAP_500", statusCode: 500) }
        repository.recommended = { [map(1)] }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        await sut.loadTask?.value
        guard case .failed(let message) = sut.uiState else { Issue.record("오류 상태가 필요하다"); return }
        #expect(!message.contains("MAP_500"))
        await sut.recommendationTask?.value
        await sut.nicknameTask?.value
        #expect(sut.recommendedMaps == [map(1)])
        repository.community = { _, _ in MapPage(maps: [map(2)], isLast: true) }
        sut.retryCommunity()
        await sut.loadTask?.value
        #expect(sut.uiState == .loaded)
        #expect(sut.communityMaps == [map(2)])
        #expect(sut.recommendedMaps == [map(1)])
        #expect(repository.recommendationCalls == 1)
        #expect(repository.nicknameCalls == 1)
    }

    @Test func 추천_실패에도_커뮤니티를_표시하고_기존_추천은_유지한다() async {
        let repository = ExploreRepositoryStub()
        repository.recommended = { throw NetworkError.http(statusCode: 500) }
        repository.community = { _, _ in MapPage(maps: [map(2)], isLast: true) }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        await sut.loadTask?.value
        await sut.recommendationTask?.value
        #expect(sut.uiState == .loaded)
        #expect(sut.communityMaps == [map(2)])
        #expect(sut.recommendedMaps.isEmpty)

        repository.recommended = { [map(1)] }
        sut.load()
        await sut.recommendationTask?.value
        repository.recommended = { throw NetworkError.http(statusCode: 500) }
        sut.load()
        await sut.loadTask?.value
        await sut.recommendationTask?.value
        #expect(sut.uiState == .loaded)
        #expect(sut.recommendedMaps == [map(1)])
    }

    @Test func 닉네임이_지연되어도_지도는_먼저_표시한다() async {
        let repository = ExploreRepositoryStub()
        let release = AsyncGate()
        repository.nickname = { await release.wait(); return "모아" }
        repository.recommended = { [map(1)] }
        repository.community = { _, _ in MapPage(maps: [map(2)], isLast: true) }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        await sut.loadTask?.value
        await sut.recommendationTask?.value
        #expect(sut.uiState == .loaded)
        #expect(sut.communityMaps == [map(2)])
        #expect(sut.recommendedMaps == [map(1)])
        #expect(sut.nickname == nil)
        await release.open()
        await sut.nicknameTask?.value
        #expect(sut.nickname == "모아")
    }

    @Test func 커뮤니티가_지연되어도_추천은_먼저_표시한다() async {
        let repository = ExploreRepositoryStub()
        let release = AsyncGate()
        repository.community = { _, _ in
            await release.wait()
            return MapPage(maps: [], isLast: true)
        }
        repository.recommended = { [map(1)] }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        await sut.recommendationTask?.value
        #expect(sut.uiState == .loading)
        #expect(sut.recommendedMaps == [map(1)])
        await release.open()
        await sut.loadTask?.value
    }

    @Test func 정렬_실패에도_추천은_유지한다() async {
        let repository = ExploreRepositoryStub()
        repository.recommended = { [map(1)] }
        repository.community = { sort, _ in
            if sort == .latest { throw NetworkError.http(statusCode: 500) }
            return MapPage(maps: [map(2)], isLast: true)
        }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        await sut.loadTask?.value
        await sut.recommendationTask?.value
        sut.changeSort(.latest)
        await sut.loadTask?.value
        guard case .failed = sut.uiState else { Issue.record("목록 오류 상태가 필요하다"); return }
        #expect(sut.recommendedMaps == [map(1)])
        #expect(repository.recommendationCalls == 1)
    }

    @Test func 취소된_추천과_닉네임은_새_결과를_덮지_않는다() async {
        let repository = ExploreRepositoryStub()
        let recommendationStarted = AsyncGate()
        let nicknameStarted = AsyncGate()
        let release = AsyncGate()
        repository.recommended = {
            await recommendationStarted.open()
            await release.wait()
            return [map(1)]
        }
        repository.nickname = {
            await nicknameStarted.open()
            await release.wait()
            return "이전"
        }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        let oldRecommendation = sut.recommendationTask
        let oldNickname = sut.nicknameTask
        await recommendationStarted.wait()
        await nicknameStarted.wait()
        repository.recommended = { [map(2)] }
        repository.nickname = { "최신" }
        sut.load()
        await sut.loadTask?.value
        await sut.recommendationTask?.value
        await sut.nicknameTask?.value
        await release.open()
        await oldRecommendation?.value
        await oldNickname?.value
        #expect(sut.recommendedMaps == [map(2)])
        #expect(sut.nickname == "최신")
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
        await sut.loadTask?.value
        #expect(sut.communityMaps == [map(9)])
        #expect(repository.communityCalls.map(\.0) == [.popular, .latest])
        #expect(repository.communityCalls.map(\.1) == [0, 0])

        sut.changeSort(.latest)
        #expect(repository.communityCalls.count == 2)
    }

    @Test func 정렬_변경은_진행중인_이전_정렬_결과를_버린다() async {
        let repository = ExploreRepositoryStub()
        let started = AsyncGate()
        let release = AsyncGate()
        repository.community = { sort, _ in
            if sort == .popular {
                await started.open()
                await release.wait()
                return MapPage(maps: [map(1)], isLast: true)
            }
            return MapPage(maps: [map(9)], isLast: true)
        }
        let sut = ExploreViewModel(repository: repository)
        sut.load()
        let old = sut.loadTask
        await started.wait()
        sut.changeSort(.latest)
        await sut.loadTask?.value
        await release.open()
        await old?.value
        #expect(sut.communityMaps == [map(9)])
        #expect(sut.uiState == .loaded)
    }

    @Test func 프로필을_고치면_제목의_이름을_바로_맞춘다() async {
        let repository = ExploreRepositoryStub()
        repository.nickname = { "모아" }
        let sut = ExploreViewModel(repository: repository)
        sut.refresh()
        await sut.nicknameTask?.value
        sut.updateNickname(" 새이름 ")
        #expect(sut.nickname == "새이름")
        #expect(repository.nicknameCalls == 1)
    }

    @Test func 늦게_온_이전_이름은_고친_이름을_덮지_않는다() async {
        let repository = ExploreRepositoryStub()
        let release = AsyncGate()
        repository.nickname = {
            await release.wait()
            return "이전"
        }
        let sut = ExploreViewModel(repository: repository)
        sut.refresh()
        let old = sut.nicknameTask
        sut.updateNickname("새이름")
        await release.open()
        await old?.value
        #expect(sut.nickname == "새이름")
    }
}
