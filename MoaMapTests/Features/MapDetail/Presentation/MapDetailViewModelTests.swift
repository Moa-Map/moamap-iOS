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
        #expect(sut.uiState.actionInProgress)
        await sut.actionTask?.value
        #expect(!sut.uiState.actionInProgress)
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
        await sut.actionTask?.value
        #expect(repository.joinCalls == 1)
    }

    @Test func 참여에_실패하면_안내하고_잠금을_푼다() async {
        let repository = MapDetailRepositoryStub()
        repository.join = { _ in throw NetworkError.connection(.notConnectedToInternet) }
        let sut = MapDetailViewModel(mapID: 7, repository: repository)
        sut.join()
        await sut.actionTask?.value
        #expect(!sut.uiState.actionInProgress)
        #expect(!sut.uiState.joinedHere)
        #expect(sut.uiState.errorMessage == "네트워크에 연결할 수 없어요")
        sut.consumeErrorMessage()
        #expect(sut.uiState.errorMessage == nil)
    }

    @Test func 나가면_이전_화면으로_돌아가라는_신호를_남긴다() async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { MapDetail.fixture(id: $0, joined: true, role: .member) }
        let sut = await loaded(repository)
        sut.leave()
        await sut.actionTask?.value
        #expect(repository.leaveCalls == 1)
        #expect(repository.deleteCalls == 0)
        #expect(sut.uiState.left)
    }

    @Test func 프라이빗_지도에_혼자_남은_방장이_나가면_지도를_삭제한다() async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { MapDetail.fixture(id: $0, joined: true, type: .private, role: .owner) }
        let sut = await loaded(repository)
        #expect(sut.uiState.leaveOutcome == .deleteMap)
        sut.leave()
        await sut.actionTask?.value
        #expect(repository.deleteCalls == 1)
        #expect(repository.leaveCalls == 0)
    }

    @Test func 나갈_수_없는_방장은_요청을_보내지_않는다() async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { MapDetail.fixture(id: $0, joined: true, role: .owner) }
        let sut = await loaded(repository)
        sut.leave()
        #expect(sut.actionTask == nil)
        #expect(repository.leaveCalls + repository.deleteCalls == 0)
    }

    @Test func 공식지도는_나가도_화면에_남아_상세를_다시_읽는다() async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { MapDetail.fixture(id: $0, joined: true, type: .official, role: .member) }
        let sut = await loaded(repository)
        #expect(sut.uiState.leaveOutcome == .leave)
        repository.detail = { MapDetail.fixture(id: $0, type: .official) }
        sut.leave()
        await sut.actionTask?.value
        #expect(!sut.uiState.left)
        #expect(sut.uiState.canJoin)
    }

    @Test func 나가기에_실패하면_안내하고_잠금을_푼다() async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { MapDetail.fixture(id: $0, joined: true, role: .member) }
        repository.leave = { _ in throw NetworkError.server(code: "MAP_001", statusCode: 400) }
        let sut = await loaded(repository)
        sut.leave()
        await sut.actionTask?.value
        #expect(!sut.uiState.actionInProgress)
        #expect(!sut.uiState.left)
        #expect(sut.uiState.errorMessage == "지도에서 나가지 못했어요")
    }

    @Test func 하트는_바로_반영하고_서버_값으로_확정한다() async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { MapDetail.fixture(id: $0, joined: true, role: .member) }
        repository.places = { _ in [MapPlace.fixture(id: 1)] }
        repository.like = { _, liked in PlaceLike(liked: liked, likeCount: 5) }
        let sut = await loaded(repository)
        sut.toggleLike(placeID: 1)
        #expect(sut.uiState.places[0].liked)
        #expect(sut.uiState.places[0].likeCount == 1)
        await sut.likeTask?.value
        #expect(sut.uiState.places[0].likeCount == 5)
    }

    @Test func 하트_요청이_실패하면_되돌린다() async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { MapDetail.fixture(id: $0, joined: true, role: .member) }
        repository.places = { _ in [MapPlace.fixture(id: 1)] }
        repository.like = { _, _ in throw NetworkError.http(statusCode: 500) }
        let sut = await loaded(repository)
        sut.toggleLike(placeID: 1)
        await sut.likeTask?.value
        #expect(!sut.uiState.places[0].liked)
        #expect(sut.uiState.places[0].likeCount == 0)
        #expect(sut.uiState.errorMessage == "하트를 반영하지 못했어요")
    }

    @Test func 같은_장소의_하트는_응답_전에_다시_보내지_않는다() async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { MapDetail.fixture(id: $0, joined: true, role: .member) }
        repository.places = { _ in [MapPlace.fixture(id: 1)] }
        let release = AsyncGate()
        repository.like = { _, liked in
            await release.wait()
            return PlaceLike(liked: liked, likeCount: 1)
        }
        let sut = await loaded(repository)
        sut.toggleLike(placeID: 1)
        sut.toggleLike(placeID: 1)
        await release.open()
        await sut.likeTask?.value
        #expect(repository.likeCalls == 1)
        #expect(sut.uiState.places[0].liked)
    }

    @Test func 참여하지_않은_지도의_하트는_안내만_한다() async {
        let repository = MapDetailRepositoryStub()
        repository.places = { _ in [MapPlace.fixture(id: 1)] }
        let sut = await loaded(repository)
        sut.toggleLike(placeID: 1)
        #expect(repository.likeCalls == 0)
        #expect(sut.uiState.errorMessage == "지도에 참여하면 하트를 누를 수 있어요")
    }

    @Test(arguments: [
        // 커뮤니티 멤버는 내가 등록한 장소만
        (MapType.community, MapRole.member, [true, false, false]),
        // 방장·관리자는 누구 장소든
        (MapType.community, MapRole.owner, [true, true, true]),
        (MapType.community, MapRole.admin, [true, true, true]),
        // 프라이빗 지도는 멤버 누구나
        (MapType.private, MapRole.member, [true, true, true]),
        // 멤버가 아니면 내 장소도 못 고친다
        (MapType.community, MapRole.none, [false, false, false])
    ])
    func 장소를_고치고_지울_수_있는지는_서버와_같은_기준으로_가린다(type: MapType, role: MapRole, expected: [Bool]) async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { MapDetail.fixture(id: $0, joined: role != .none, type: type, role: role) }
        repository.places = { _ in [MapPlace.fixture(id: 1, authorID: 42), MapPlace.fixture(id: 2, authorID: 9), MapPlace.fixture(id: 3)] }
        let sut = await loaded(repository, myUserID: 42)
        #expect(sut.uiState.places.map(sut.uiState.canModify) == expected)
    }

    @Test func 로그인한_사용자를_모르면_멤버는_어느_장소도_고칠_수_없다() async {
        let repository = MapDetailRepositoryStub()
        repository.detail = { MapDetail.fixture(id: $0, joined: true, role: .member) }
        repository.places = { _ in [MapPlace.fixture(id: 1), MapPlace.fixture(id: 2, authorID: 42)] }
        let sut = await loaded(repository)
        #expect(sut.uiState.places.map(sut.uiState.canModify) == [false, false])
    }

    @Test func 수정한_값만_반영하고_그사이_바뀐_하트는_남긴다() async {
        let repository = MapDetailRepositoryStub()
        repository.places = { _ in [MapPlace.fixture(id: 1), MapPlace.fixture(id: 2)] }
        let sut = await loaded(repository)
        var edited = MapPlace.fixture(id: 2)
        edited.tags = ["카페"]
        edited.description = "메모"
        edited.photoURLs = [URL(string: "https://file/a")!]
        edited.liked = true
        edited.likeCount = 3
        sut.applyEdit(edited)
        let place = sut.uiState.places[1]
        #expect(place.tags == ["카페"] && place.description == "메모" && place.photoURLs == edited.photoURLs)
        #expect(!place.liked && place.likeCount == 0)
        #expect(sut.uiState.places[0] == MapPlace.fixture(id: 1))
    }

    @Test func 장소를_지우면_목록에서_빼고_지도를_다시_읽는다() async {
        let repository = MapDetailRepositoryStub()
        repository.places = { _ in [MapPlace.fixture(id: 1, authorID: 42), MapPlace.fixture(id: 2)] }
        let sut = await loaded(repository, myUserID: 42)
        let detailCalls = repository.detailCalls
        let release = AsyncGate()
        repository.places = { _ in
            await release.wait()
            return [MapPlace.fixture(id: 2)]
        }
        sut.deletePlace(placeID: 1)
        await sut.actionTask?.value
        #expect(repository.deletedPlaceIDs == [1])
        #expect(sut.uiState.places == [MapPlace.fixture(id: 2)])
        #expect(!sut.uiState.actionInProgress)
        await release.open()
        await sut.loadTask?.value
        #expect(repository.detailCalls == detailCalls + 1)
    }

    @Test func 장소_삭제에_실패하면_그대로_두고_안내한다() async {
        let repository = MapDetailRepositoryStub()
        repository.places = { _ in [MapPlace.fixture(id: 1, authorID: 42)] }
        repository.removePlace = { _ in throw NetworkError.http(statusCode: 403) }
        let sut = await loaded(repository, myUserID: 42)
        sut.deletePlace(placeID: 1)
        await sut.actionTask?.value
        #expect(sut.uiState.places == [MapPlace.fixture(id: 1, authorID: 42)])
        #expect(sut.uiState.errorMessage == "장소를 삭제하지 못했어요")
        #expect(!sut.uiState.actionInProgress)
    }

    private func loaded(_ repository: MapDetailRepositoryStub, myUserID: Int64? = nil) async -> MapDetailViewModel {
        let sut = MapDetailViewModel(mapID: 7, repository: repository, currentUserStore: MemoryCurrentUserStore(myUserID))
        sut.retry()
        await sut.loadTask?.value
        return sut
    }
}
