import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MapIntroViewModelTests {
    @Test func 만들어지기만_하면_조회하지_않는다() {
        let repository = MapDetailRepositoryStub()
        _ = MapIntroViewModel(mapID: 7, repository: repository)
        #expect(repository.detailCalls == 0)
        #expect(repository.placeCalls == 0)
    }

    @Test func 지도와_장소를_함께_읽고_목록은_앞의_4개만_쓴다() async {
        let repository = MapDetailRepositoryStub()
        repository.places = { _ in (1...5).map { MapPlace.fixture(id: $0) } }
        let sut = MapIntroViewModel(mapID: 7, repository: repository)
        sut.refresh()
        #expect(sut.uiState.map == .loading)
        await sut.loadTask?.value
        #expect(sut.uiState.map == .loaded(.fixture(id: 7)))
        #expect(sut.uiState.places.count == 5)
        #expect(sut.uiState.previewPlaces.map(\.id) == [1, 2, 3, 4])
        #expect(sut.uiState.hasMorePlaces)
    }

    @Test func 장소가_적으면_더보기를_띄우지_않는다() async {
        let repository = MapDetailRepositoryStub()
        repository.places = { _ in (1...4).map { MapPlace.fixture(id: $0) } }
        let sut = MapIntroViewModel(mapID: 7, repository: repository)
        sut.refresh()
        await sut.loadTask?.value
        #expect(!sut.uiState.hasMorePlaces)
    }

    @Test func 장소_조회만_실패해도_지도는_보여준다() async {
        let repository = MapDetailRepositoryStub()
        repository.places = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = MapIntroViewModel(mapID: 7, repository: repository)
        sut.refresh()
        await sut.loadTask?.value
        #expect(sut.uiState.map == .loaded(.fixture(id: 7)))
        #expect(sut.uiState.places.isEmpty)
    }

    @Test func 지도_조회에_실패하면_서버_원문_없이_오류를_보이고_재시도로_복구한다() async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { _ in throw NetworkError.server(code: "COMMON_005", statusCode: 500) }
        let sut = MapIntroViewModel(mapID: 7, repository: repository)
        sut.refresh()
        await sut.loadTask?.value
        #expect(sut.uiState.map == .failed("지도를 불러오지 못했어요"))

        repository.detail = { MapDetail.fixture(id: $0) }
        sut.retry()
        #expect(sut.uiState.map == .loading)
        await sut.loadTask?.value
        #expect(sut.uiState.map == .loaded(.fixture(id: 7)))
    }

    @Test func 연결_실패는_네트워크_안내를_보인다() async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { _ in throw NetworkError.connection(.notConnectedToInternet) }
        let sut = MapIntroViewModel(mapID: 7, repository: repository)
        sut.refresh()
        await sut.loadTask?.value
        #expect(sut.uiState.map == .failed("네트워크에 연결할 수 없어요"))
    }

    @Test func 돌아와서_다시_읽는_동안에는_보던_지도가_남고_실패해도_지우지_않는다() async {
        let repository = MapDetailRepositoryStub()
        let sut = MapIntroViewModel(mapID: 7, repository: repository)
        sut.refresh()
        await sut.loadTask?.value

        repository.detail = { _ in throw NetworkError.http(statusCode: 500) }
        sut.refresh()
        #expect(sut.uiState.map == .loaded(.fixture(id: 7)))
        await sut.loadTask?.value
        #expect(sut.uiState.map == .loaded(.fixture(id: 7)))
    }

    @Test func 다시_읽으면_참여_여부가_갱신된다() async {
        let repository = MapDetailRepositoryStub()
        let sut = MapIntroViewModel(mapID: 7, repository: repository)
        sut.refresh()
        await sut.loadTask?.value

        repository.detail = { MapDetail.fixture(id: $0, joined: true) }
        sut.refresh()
        await sut.loadTask?.value
        #expect(sut.uiState.map.map?.joined == true)
    }

    @Test func 참여하면_상세로_넘어갈_신호를_낸다() async {
        let repository = MapDetailRepositoryStub()
        let sut = MapIntroViewModel(mapID: 7, repository: repository)
        sut.join()
        #expect(sut.uiState.joining)
        await sut.joinTask?.value
        #expect(!sut.uiState.joining)
        #expect(sut.uiState.joined)
    }

    @Test func 요청이_도는_동안_다시_눌러도_한_번만_참여한다() async {
        let repository = MapDetailRepositoryStub()
        let release = AsyncGate()
        repository.join = { _ in await release.wait() }
        let sut = MapIntroViewModel(mapID: 7, repository: repository)
        sut.join()
        sut.join()
        await release.open()
        await sut.joinTask?.value
        #expect(repository.joinCalls == 1)
    }

    @Test func 참여에_실패하면_안내가_뜨고_넘어가지_않는다() async {
        let repository = MapDetailRepositoryStub()
        repository.join = { _ in throw NetworkError.server(code: "MAP_403", statusCode: 403) }
        let sut = MapIntroViewModel(mapID: 7, repository: repository)
        sut.join()
        await sut.joinTask?.value
        #expect(!sut.uiState.joined)
        #expect(!sut.uiState.joining)
        #expect(sut.uiState.errorMessage == "지도에 참여하지 못했어요")

        sut.consumeErrorMessage()
        #expect(sut.uiState.errorMessage == nil)
    }
}
