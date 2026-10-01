import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MapDetailViewModelTests {
    @Test func 지도와_장소를_함께_읽는다() async {
        let repository = MapDetailRepositoryStub()
        repository.places = { _ in [MapPlace.fixture(id: 1)] }
        let sut = MapDetailViewModel(mapID: 7, repository: repository)
        sut.retry()
        #expect(sut.uiState.map == .loading)
        await sut.loadTask?.value
        #expect(sut.uiState.map == .loaded(.fixture(id: 7)))
        #expect(sut.uiState.places == [MapPlace.fixture(id: 1)])
    }

    @Test func 장소_조회만_실패해도_지도는_열리고_직전_장소는_남는다() async {
        let repository = MapDetailRepositoryStub()
        repository.places = { _ in [MapPlace.fixture(id: 1)] }
        let sut = MapDetailViewModel(mapID: 7, repository: repository)
        sut.retry()
        await sut.loadTask?.value

        repository.places = { _ in throw NetworkError.http(statusCode: 500) }
        sut.refresh()
        await sut.loadTask?.value
        #expect(sut.uiState.map == .loaded(.fixture(id: 7)))
        #expect(sut.uiState.places == [MapPlace.fixture(id: 1)])
    }

    @Test func 지도_조회에_실패하면_서버_원문_없이_오류를_보인다() async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { _ in throw NetworkError.server(code: "COMMON_005", statusCode: 500) }
        let sut = MapDetailViewModel(mapID: 7, repository: repository)
        sut.retry()
        await sut.loadTask?.value
        #expect(sut.uiState.map == .failed("지도를 불러오지 못했어요"))
    }

    @Test func 다시_읽는_동안에는_보던_지도가_남는다() async {
        let repository = MapDetailRepositoryStub()
        let sut = MapDetailViewModel(mapID: 7, repository: repository)
        sut.retry()
        await sut.loadTask?.value
        sut.refresh()
        #expect(sut.uiState.map == .loaded(.fixture(id: 7)))
        await sut.loadTask?.value
    }

    @Test func 늦게_온_이전_응답은_최신_결과를_덮지_않는다() async {
        let repository = MapDetailRepositoryStub()
        let started = AsyncGate()
        let release = AsyncGate()
        repository.detail = { id in
            await started.open()
            await release.wait()
            return MapDetail.fixture(id: id, title: "이전")
        }
        let sut = MapDetailViewModel(mapID: 7, repository: repository)
        sut.retry()
        let old = sut.loadTask
        await started.wait()
        repository.detail = { MapDetail.fixture(id: $0, title: "최신") }
        sut.refresh()
        await sut.loadTask?.value
        await release.open()
        await old?.value
        #expect(sut.uiState.map.map?.title == "최신")
    }

    @Test func 참여하면_상세를_다시_읽고_이_화면에서_참여했음을_남긴다() async {
        let repository = MapDetailRepositoryStub()
        let sut = MapDetailViewModel(mapID: 7, repository: repository)
        sut.retry()
        await sut.loadTask?.value
        #expect(sut.uiState.canJoin)

        repository.detail = { MapDetail.fixture(id: $0, joined: true) }
        sut.join()
        #expect(sut.uiState.joining)
        await sut.joinTask?.value
        #expect(!sut.uiState.joining)
        #expect(sut.uiState.joinedHere)
        #expect(!sut.uiState.canJoin)
        #expect(repository.detailCalls == 2)
    }

    @Test func 참여_요청이_도는_동안_다시_눌러도_한_번만_보낸다() async {
        let repository = MapDetailRepositoryStub()
        let release = AsyncGate()
        repository.join = { _ in await release.wait() }
        let sut = MapDetailViewModel(mapID: 7, repository: repository)
        sut.join()
        sut.join()
        await release.open()
        await sut.joinTask?.value
        #expect(repository.joinCalls == 1)
    }

    @Test func 참여에_실패하면_안내하고_잠금을_푼다() async {
        let repository = MapDetailRepositoryStub()
        repository.join = { _ in throw NetworkError.connection(.notConnectedToInternet) }
        let sut = MapDetailViewModel(mapID: 7, repository: repository)
        sut.join()
        await sut.joinTask?.value
        #expect(!sut.uiState.joining)
        #expect(!sut.uiState.joinedHere)
        #expect(sut.uiState.errorMessage == "네트워크에 연결할 수 없어요")
        sut.consumeErrorMessage()
        #expect(sut.uiState.errorMessage == nil)
    }
}
