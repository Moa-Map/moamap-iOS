import Foundation
import Testing
@testable import MoaMap

private func map(_ id: Int64, tags: [String] = []) -> MapSummary {
    MapSummary(id: id, title: "지도 \(id)", imageURL: nil, tags: tags, memberCount: 0, placeCount: 0)
}

private actor DurationLog {
    private(set) var values: [Duration] = []
    func append(_ value: Duration) { values.append(value) }
}

@MainActor
struct CommunityMapListViewModelTests {
    private typealias Request = ExploreRepositoryStub.CommunityRequest
    private typealias SearchRequest = ExploreRepositoryStub.SearchRequest

    @Test func 처음_보이면_전체_인기순_첫_20개를_읽는다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in MapPage(maps: [map(1)], isLast: true) }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        #expect(sut.uiState.list == .loading)
        await sut.loadTask?.value
        #expect(sut.uiState.list == .loaded([map(1)]))
        #expect(sut.uiState.paging == .end)
        #expect(repository.communityRequests == [Request(tag: nil, sort: .popular, page: 0, size: 20)])
    }

    @Test func 첫_페이지를_받는_중이면_다시_보여도_또_요청하지_않는다() async {
        let repository = ExploreRepositoryStub()
        let release = AsyncGate()
        repository.community = { _, _ in
            await release.wait()
            return MapPage(maps: [], isLast: true)
        }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        sut.refresh()
        await release.open()
        await sut.loadTask?.value
        #expect(repository.communityRequests.count == 1)
    }

    @Test func 칩은_거르지_않은_첫_목록의_태그를_많이_쓰인_순으로_만든다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in
            MapPage(maps: [map(1, tags: ["산책", "카페"]), map(2, tags: ["카페", "데이트"]), map(3, tags: ["데이트", "카페"])], isLast: true)
        }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        await sut.loadTask?.value
        #expect(sut.uiState.tags == ["카페", "데이트", "산책"])
    }

    @Test func 칩을_고르면_그_태그로_처음부터_다시_읽고_칩_줄은_그대로_둔다() async {
        let repository = ExploreRepositoryStub()
        repository.communityByTag = { tag, _, _, _ in
            tag == nil
                ? MapPage(maps: [map(1, tags: ["카페"]), map(2, tags: ["산책"])], isLast: true)
                : MapPage(maps: [map(1, tags: ["카페"])], isLast: true)
        }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        await sut.loadTask?.value

        sut.selectTag("카페")
        #expect(sut.uiState.list == .loading)
        await sut.loadTask?.value
        #expect(sut.uiState.selectedTag == "카페")
        #expect(sut.uiState.maps == [map(1, tags: ["카페"])])
        #expect(sut.uiState.tags == ["카페", "산책"])
        #expect(repository.communityRequests.last == Request(tag: "카페", sort: .popular, page: 0, size: 20))
    }

    @Test func 전체를_누르면_태그_없이_다시_읽는다() async {
        let repository = ExploreRepositoryStub()
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        await sut.loadTask?.value
        sut.selectTag("카페")
        await sut.loadTask?.value
        sut.selectTag(nil)
        await sut.loadTask?.value
        #expect(sut.uiState.selectedTag == nil)
        #expect(repository.communityRequests.last?.tag == nil)
        #expect(repository.communityRequests.count == 3)
    }

    @Test func 정렬을_바꾸면_고른_태그_그대로_처음부터_다시_읽는다() async {
        let repository = ExploreRepositoryStub()
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        await sut.loadTask?.value
        sut.selectTag("카페")
        await sut.loadTask?.value
        sut.selectSort(.latest)
        await sut.loadTask?.value
        #expect(repository.communityRequests.last == Request(tag: "카페", sort: .latest, page: 0, size: 20))
    }

    @Test func 같은_칩이나_정렬을_다시_누르면_다시_읽지_않는다() async {
        let repository = ExploreRepositoryStub()
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        await sut.loadTask?.value
        sut.selectTag(nil)
        sut.selectSort(.popular)
        #expect(repository.communityRequests.count == 1)
    }

    @Test func 끝에_닿으면_다음_페이지를_이어_붙이고_겹친_지도는_뺀다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, page in
            page == 0
                ? MapPage(maps: [map(1), map(2)], isLast: false)
                : MapPage(maps: [map(2), map(3)], isLast: true)
        }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        await sut.loadTask?.value

        sut.loadMore()
        #expect(sut.uiState.paging == .loading)
        await sut.loadTask?.value
        #expect(sut.uiState.maps == [map(1), map(2), map(3)])
        #expect(sut.uiState.paging == .end)

        sut.loadMore()
        #expect(repository.communityRequests.map(\.page) == [0, 1])
    }

    @Test func 다음_페이지를_못_받으면_받은_목록은_두고_실패만_표시한다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, page in
            if page > 0 { throw NetworkError.connection(.notConnectedToInternet) }
            return MapPage(maps: [map(1)], isLast: false)
        }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        await sut.loadTask?.value
        sut.loadMore()
        await sut.loadTask?.value
        #expect(sut.uiState.maps == [map(1)])
        #expect(sut.uiState.paging == .failed)

        repository.community = { _, _ in MapPage(maps: [map(2)], isLast: true) }
        sut.loadMore()
        await sut.loadTask?.value
        #expect(sut.uiState.maps == [map(1), map(2)])
        #expect(repository.communityRequests.map(\.page) == [0, 1, 1])
    }

    @Test func 첫_페이지를_못_받았으면_다음_페이지를_부르지_않고_재시도로_복구한다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in throw NetworkError.server(code: "COMMON_005", statusCode: 500) }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        await sut.loadTask?.value
        guard case .failed(let message) = sut.uiState.list else { Issue.record("오류 상태가 필요하다"); return }
        #expect(!message.contains("COMMON_005"))

        sut.loadMore()
        #expect(repository.communityRequests.count == 1)

        repository.community = { _, _ in MapPage(maps: [map(1)], isLast: true) }
        sut.retry()
        await sut.loadTask?.value
        #expect(sut.uiState.list == .loaded([map(1)]))
    }

    @Test func 돌아오면_받아_둔_만큼을_한_번에_다시_읽는다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in MapPage(maps: [map(1)], isLast: false) }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        await sut.loadTask?.value
        sut.loadMore()
        await sut.loadTask?.value

        repository.community = { _, _ in MapPage(maps: [map(1), map(2), map(3)], isLast: true) }
        sut.refresh()
        #expect(sut.uiState.maps == [map(1)])
        await sut.loadTask?.value
        #expect(sut.uiState.maps == [map(1), map(2), map(3)])
        #expect(sut.uiState.paging == .end)
        #expect(repository.communityRequests.last == Request(tag: nil, sort: .popular, page: 0, size: 40))
    }

    @Test func 다시_읽기가_실패해도_보던_목록을_지우지_않는다() async {
        let repository = ExploreRepositoryStub()
        repository.community = { _, _ in MapPage(maps: [map(1)], isLast: true) }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        await sut.loadTask?.value

        repository.community = { _, _ in throw NetworkError.http(statusCode: 500) }
        sut.refresh()
        await sut.loadTask?.value
        #expect(sut.uiState.list == .loaded([map(1)]))
    }

    @Test func 칩을_연달아_바꾸면_늦게_온_이전_응답은_버리고_마지막_선택만_남는다() async {
        let repository = ExploreRepositoryStub()
        let started = AsyncGate()
        let release = AsyncGate()
        repository.communityByTag = { tag, _, _, _ in
            if tag == "카페" {
                await started.open()
                await release.wait()
                return MapPage(maps: [map(1)], isLast: true)
            }
            return MapPage(maps: [map(2)], isLast: true)
        }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.selectTag("카페")
        let old = sut.loadTask
        await started.wait()
        sut.selectTag("산책")
        await sut.loadTask?.value
        await release.open()
        await old?.value
        #expect(sut.uiState.selectedTag == "산책")
        #expect(sut.uiState.list == .loaded([map(2)]))
    }

    // MARK: 검색

    @Test func 입력을_멈추면_300ms_뒤에_전체에서_검색한다() async {
        let repository = ExploreRepositoryStub()
        repository.search = { _, _ in MapPage(maps: [map(1)], isLast: true) }
        let waited = DurationLog()
        let release = AsyncGate()
        let sut = CommunityMapListViewModel(repository: repository, sleep: { duration in
            await waited.append(duration)
            await release.wait()
        })
        sut.updateQuery("카페")
        #expect(sut.uiState.query == "카페")
        #expect(repository.searchRequests.isEmpty)

        let pending = sut.searchTask
        await release.open()
        await pending?.value
        await sut.loadTask?.value
        #expect(await waited.values == [.milliseconds(300)])
        #expect(repository.searchRequests == [SearchRequest(keyword: "카페", page: 0, size: 20)])
        #expect(sut.uiState.searchKeyword == "카페")
        #expect(sut.uiState.list == .loaded([map(1)]))
    }

    @Test func 기다리는_사이_다시_입력하면_이전_검색은_버린다() async {
        let repository = ExploreRepositoryStub()
        let release = AsyncGate()
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in await release.wait() })
        sut.updateQuery("카")
        let first = sut.searchTask
        sut.updateQuery("카페")
        let second = sut.searchTask
        await release.open()
        await first?.value
        await second?.value
        await sut.loadTask?.value
        #expect(repository.searchRequests.map(\.keyword) == ["카페"])
    }

    @Test func 검색_버튼은_기다리지_않고_바로_찾는다() async {
        let repository = ExploreRepositoryStub()
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
        sut.updateQuery("카페")
        sut.searchNow()
        #expect(sut.searchTask == nil)
        #expect(sut.uiState.list == .loading)
        await sut.loadTask?.value
        #expect(repository.searchRequests == [SearchRequest(keyword: "카페", page: 0, size: 20)])
    }

    @Test func 자동_검색_뒤_검색_버튼을_눌러도_같은_검색어면_다시_요청하지_않는다() async {
        let repository = ExploreRepositoryStub()
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.updateQuery("카페")
        await sut.searchTask?.value
        await sut.loadTask?.value
        sut.searchNow()
        sut.updateQuery("카페 ")
        await sut.searchTask?.value
        await sut.loadTask?.value
        #expect(repository.searchRequests.count == 1)
    }

    @Test func 검색어를_다_지우면_기다리지_않고_고른_태그와_정렬의_목록으로_돌아간다() async {
        let repository = ExploreRepositoryStub()
        repository.communityByTag = { _, _, _, _ in MapPage(maps: [map(1, tags: ["카페"])], isLast: true) }
        repository.search = { _, _ in MapPage(maps: [map(2, tags: ["산책"])], isLast: true) }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
        sut.refresh()
        await sut.loadTask?.value
        sut.selectTag("카페")
        sut.selectSort(.latest)
        await sut.loadTask?.value

        sut.updateQuery("산책")
        sut.searchNow()
        await sut.loadTask?.value
        #expect(sut.uiState.isSearching)
        #expect(sut.uiState.selectedTag == "카페")
        #expect(sut.uiState.sort == .latest)

        sut.updateQuery("")
        #expect(sut.searchTask == nil)
        #expect(!sut.uiState.isSearching)
        #expect(sut.uiState.list == .loading)
        await sut.loadTask?.value
        #expect(repository.communityRequests.last == Request(tag: "카페", sort: .latest, page: 0, size: 20))
        #expect(sut.uiState.maps == [map(1, tags: ["카페"])])
    }

    @Test func 검색어는_50자로_자르고_앞뒤_공백을_빼고_찾는다() async {
        let repository = ExploreRepositoryStub()
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.updateQuery(String(repeating: "가", count: 60))
        #expect(sut.uiState.query == String(repeating: "가", count: 50))

        sut.updateQuery("  카페  ")
        sut.searchNow()
        await sut.loadTask?.value
        #expect(sut.uiState.query == "  카페  ")
        #expect(repository.searchRequests.map(\.keyword) == ["카페"])
    }

    @Test func 공백만_있으면_검색하지_않는다() async {
        let repository = ExploreRepositoryStub()
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.refresh()
        await sut.loadTask?.value
        sut.updateQuery("   ")
        #expect(sut.searchTask == nil)
        sut.searchNow()
        await sut.loadTask?.value
        #expect(repository.searchRequests.isEmpty)
        #expect(repository.communityRequests.count == 1)
        #expect(!sut.uiState.isSearching)
    }

    @Test func 검색_결과로_칩을_만들지_않고_다음_페이지도_검색으로_받는다() async {
        let repository = ExploreRepositoryStub()
        repository.search = { _, page in
            page == 0
                ? MapPage(maps: [map(1, tags: ["카페"])], isLast: false)
                : MapPage(maps: [map(2, tags: ["산책"])], isLast: true)
        }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.updateQuery("지도")
        sut.searchNow()
        await sut.loadTask?.value
        sut.loadMore()
        await sut.loadTask?.value
        #expect(sut.uiState.tags.isEmpty)
        #expect(sut.uiState.maps == [map(1, tags: ["카페"]), map(2, tags: ["산책"])])
        #expect(sut.uiState.paging == .end)
        #expect(repository.searchRequests.map(\.page) == [0, 1])
        #expect(repository.communityRequests.isEmpty)
    }

    @Test func 검색_첫_페이지를_못_받으면_서버_메시지_없이_실패를_보인다() async {
        let repository = ExploreRepositoryStub()
        repository.search = { _, _ in throw NetworkError.server(code: "COMMON_005", statusCode: 500) }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.updateQuery("카페")
        sut.searchNow()
        await sut.loadTask?.value
        guard case .failed(let message) = sut.uiState.list else { Issue.record("오류 상태가 필요하다"); return }
        #expect(!message.contains("COMMON_005"))

        repository.search = { _, _ in MapPage(maps: [map(1)], isLast: true) }
        sut.retry()
        await sut.loadTask?.value
        #expect(sut.uiState.list == .loaded([map(1)]))
        #expect(repository.searchRequests.count == 2)
    }

    @Test func 검색어를_바꾸면_늦게_온_이전_검색_응답은_버린다() async {
        let repository = ExploreRepositoryStub()
        let started = AsyncGate()
        let release = AsyncGate()
        repository.search = { keyword, _ in
            if keyword == "카" {
                await started.open()
                await release.wait()
                return MapPage(maps: [map(1)], isLast: true)
            }
            return MapPage(maps: [map(2)], isLast: true)
        }
        let sut = CommunityMapListViewModel(repository: repository, sleep: { _ in })
        sut.updateQuery("카")
        sut.searchNow()
        let old = sut.loadTask
        await started.wait()
        sut.updateQuery("카페")
        sut.searchNow()
        await sut.loadTask?.value
        await release.open()
        await old?.value
        #expect(sut.uiState.searchKeyword == "카페")
        #expect(sut.uiState.list == .loaded([map(2)]))
    }

    @Test func 태그가_많으면_많이_쓰인_순으로_상한까지만_칩이_된다() {
        let maps = (0..<12).map { index in
            map(Int64(index), tags: (0...index).map { "태그\($0)" })
        }
        let tags = CommunityMapListViewModel.tagsByFrequency(maps, limit: 3)
        #expect(tags == ["태그0", "태그1", "태그2"])
    }
}
