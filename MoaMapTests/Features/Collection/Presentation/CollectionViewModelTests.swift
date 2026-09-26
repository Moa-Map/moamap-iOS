import Foundation
import Testing
@testable import MoaMap

@MainActor
struct CollectionViewModelTests {
    private func map(_ id: Int64, personal: Bool = false) -> MyMap {
        MyMap(id: id, title: "지도", imageURL: nil, memberCount: 1, placeCount: 0, official: false, personal: personal)
    }

    @Test func 첫_조회와_탭_전환은_필요한_목록만_요청한다() async throws {
        let repository = CollectionRepositoryStub()
        let community = [map(1)]
        repository.fetch = { $0 == .community ? community : [] }
        let sut = CollectionViewModel(repository: repository)
        #expect(repository.calls.isEmpty)
        sut.loadIfNeeded()
        #expect(sut.uiState.currentMaps == .loading)
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .loaded(community))
        sut.selectTab(.private)
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .loaded([]))
        sut.selectTab(.community)
        sut.loadIfNeeded()
        #expect(sut.uiState.currentMaps == .loaded(community))
        #expect(repository.calls == [.community, .private])
    }

    @Test func 오류는_서버_원문을_숨기고_현재_탭만_재시도한다() async throws {
        let repository = CollectionRepositoryStub()
        let sut = CollectionViewModel(repository: repository)
        sut.loadIfNeeded()
        try await sut.loadTask?.value
        repository.fetch = { _ in throw NetworkError.server(code: "COMMON_005", statusCode: 500) }
        sut.selectTab(.private)
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .failed("지도 목록을 불러오지 못했어요"))
        #expect(sut.uiState.community == .loaded([]))
        repository.fetch = { _ in [] }
        sut.retry()
        #expect(sut.uiState.currentMaps == .loading)
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .loaded([]))
        #expect(repository.calls == [.community, .private, .private])
    }

    @Test func 새로고침_실패는_기존_목록을_유지하고_다른_탭은_다음에_갱신한다() async throws {
        let repository = CollectionRepositoryStub()
        let maps = [map(1)]
        repository.fetch = { _ in maps }
        let sut = CollectionViewModel(repository: repository)
        sut.selectTab(.private)
        try await sut.loadTask?.value
        sut.selectTab(.community)
        try await sut.loadTask?.value
        repository.fetch = { _ in throw NetworkError.http(statusCode: 500) }
        sut.refresh()
        #expect(sut.uiState.currentMaps == .loaded(maps))
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .loaded(maps))
        repository.fetch = { _ in [] }
        sut.selectTab(.private)
        try await sut.loadTask?.value
        #expect(sut.uiState.currentMaps == .loaded([]))
        #expect(repository.calls == [.private, .community, .community, .private])
    }

    @Test(arguments: [false, true])
    func 취소된_이전_요청의_성공과_실패는_최신_상태를_덮지_않는다(fails: Bool) async throws {
        let repository = CollectionRepositoryStub()
        let started = AsyncGate()
        let release = AsyncGate()
        repository.fetch = { _ in
            await started.open()
            await release.wait()
            if fails { throw NetworkError.http(statusCode: 500) }
            return []
        }
        let sut = CollectionViewModel(repository: repository)
        sut.loadIfNeeded()
        let oldTask = sut.loadTask
        await started.wait()
        let maps = [map(2)]
        repository.fetch = { _ in maps }
        sut.retry()
        try await sut.loadTask?.value
        await release.open()
        await #expect(throws: CancellationError.self) { try await oldTask?.value }
        #expect(sut.uiState.currentMaps == .loaded(maps))
    }

    @Test func 탭을_바꿔도_진행중인_다른_탭_요청은_유지한다() async throws {
        let repository = CollectionRepositoryStub()
        let release = AsyncGate()
        let maps = [map(1)]
        repository.fetch = { type in
            if type == .community { await release.wait(); return maps }
            return []
        }
        let sut = CollectionViewModel(repository: repository)
        sut.loadIfNeeded()
        let communityTask = sut.loadTask
        sut.selectTab(.private)
        try await sut.loadTask?.value
        #expect(sut.uiState.privateMaps == .loaded([]))
        #expect(sut.uiState.community == .loading)
        await release.open()
        try await communityTask?.value
        #expect(sut.uiState.community == .loaded(maps))
        #expect(sut.uiState.selectedTab == .private)
    }

    @Test func 개인지도는_전체_목록에_중복되지_않고_순서를_유지한다() {
        let personal = map(1, personal: true)
        let others = [map(2), map(3)]
        let sections = PrivateMapSections(maps: [others[0], personal, others[1]])
        #expect(sections.personal == [personal])
        #expect(sections.others == others)
        #expect(PrivateMapSections(maps: []).personal.isEmpty)
    }
}
