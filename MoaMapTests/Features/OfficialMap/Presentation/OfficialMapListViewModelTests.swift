import Foundation
import Testing
@testable import MoaMap

private func map(_ id: Int64) -> OfficialMap {
    OfficialMap(id: id, title: "지도 \(id)", description: "", imageURL: nil, joined: false)
}

private struct StubError: Error {}

@MainActor
struct OfficialMapListViewModelTests {
    @Test func 처음_보이면_목록을_읽는다() async {
        let repository = OfficialMapRepositoryStub()
        repository.fetch = { [map(6)] }
        let sut = OfficialMapListViewModel(repository: repository)
        sut.refresh()
        #expect(sut.uiState == .loading)
        await sut.loadTask?.value
        #expect(sut.uiState == .loaded([map(6)]))
    }

    @Test func 목록을_받는_중이면_다시_보여도_또_요청하지_않는다() async {
        let repository = OfficialMapRepositoryStub()
        let release = AsyncGate()
        repository.fetch = {
            await release.wait()
            return []
        }
        let sut = OfficialMapListViewModel(repository: repository)
        sut.refresh()
        sut.refresh()
        await release.open()
        await sut.loadTask?.value
        #expect(repository.fetchCalls == 1)
    }

    @Test func 못_받으면_안내를_띄우고_다시_시도하면_다시_읽는다() async {
        let repository = OfficialMapRepositoryStub()
        repository.fetch = { throw StubError() }
        let sut = OfficialMapListViewModel(repository: repository)
        sut.refresh()
        await sut.loadTask?.value
        #expect(sut.uiState == .failed("공식지도를 불러오지 못했어요"))

        repository.fetch = { [map(6)] }
        sut.retry()
        #expect(sut.uiState == .loading)
        await sut.loadTask?.value
        #expect(sut.uiState == .loaded([map(6)]))
    }

    @Test func 돌아와서_다시_읽을_때는_보던_목록을_지우지_않는다() async {
        let repository = OfficialMapRepositoryStub()
        repository.fetch = { [map(6)] }
        let sut = OfficialMapListViewModel(repository: repository)
        sut.refresh()
        await sut.loadTask?.value

        repository.fetch = { throw StubError() }
        sut.refresh()
        #expect(sut.uiState == .loaded([map(6)]))
        await sut.loadTask?.value
        #expect(sut.uiState == .loaded([map(6)]))
    }
}
