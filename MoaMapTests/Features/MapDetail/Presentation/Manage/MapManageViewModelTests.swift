import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MapManageViewModelTests {
    private func activity(_ type: MapActivityType, place: String? = "커피나무") -> MapActivity {
        MapActivity(type: type, occurredAt: nil, actorName: nil, actorImageURL: nil, placeID: 1, placeName: place)
    }

    @Test func 활동_내역은_처음_열_때_한_번만_읽는다() async {
        let repository = MapActivityRepositoryStub()
        repository.activities = { _ in [self.activity(.placeAdded)] }
        let sut = MapActivityViewModel(mapID: 7, repository: repository, now: Date.init)
        sut.loadOnce()
        await sut.loadTask?.value
        sut.loadOnce()
        #expect(repository.fetchCalls == 1)
        #expect(sut.uiState == MapActivityUiState(loading: false, activities: [activity(.placeAdded)]))
    }

    @Test(arguments: [
        (NetworkError.server(code: "PLACE_002", statusCode: 403) as any Error, "지도에 참여해야 활동 내역을 볼 수 있어요"),
        (NetworkError.http(statusCode: 500) as any Error, "활동 내역을 불러오지 못했어요")
    ])
    func 활동_내역을_못_읽으면_원인에_맞게_안내한다(error: any Error, message: String) async {
        let repository = MapActivityRepositoryStub()
        repository.activities = { _ in throw error }
        let sut = MapActivityViewModel(mapID: 7, repository: repository, now: Date.init)
        sut.loadOnce()
        await sut.loadTask?.value
        #expect(sut.uiState.errorMessage == message)
        repository.activities = { _ in [] }
        sut.retry()
        #expect(sut.uiState.loading)
        await sut.loadTask?.value
        #expect(sut.uiState.errorMessage == nil)
    }

    @Test func 수락하면_요청을_빼고_수락_수를_올린다() async {
        let repository = PendingPlaceRepositoryStub()
        repository.pending = { _ in [.fixture(id: 1), .fixture(id: 2)] }
        let sut = PendingRequestViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        sut.approve(placeID: 1)
        #expect(sut.uiState.processing)
        await sut.actionTask?.value
        #expect(sut.uiState.requests == [.fixture(id: 2)])
        #expect(sut.uiState.approvedCount == 1)
        sut.reject(placeID: 2)
        await sut.actionTask?.value
        #expect(sut.uiState.requests.isEmpty)
        #expect(sut.uiState.approvedCount == 1)
        #expect(repository.rejected == [2])
    }

    @Test func 처리가_도는_동안_다른_요청은_보내지_않는다() async {
        let repository = PendingPlaceRepositoryStub()
        let release = AsyncGate()
        repository.action = { _ in await release.wait() }
        let sut = PendingRequestViewModel(mapID: 7, repository: repository)
        sut.approve(placeID: 1)
        sut.reject(placeID: 2)
        await release.open()
        await sut.actionTask?.value
        #expect(repository.approved == [1])
        #expect(repository.rejected.isEmpty)
    }

    @Test func 처리에_실패하면_요청을_남기고_안내한다() async {
        let repository = PendingPlaceRepositoryStub()
        repository.pending = { _ in [.fixture(id: 1)] }
        repository.action = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = PendingRequestViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        sut.approve(placeID: 1)
        await sut.actionTask?.value
        #expect(sut.uiState.requests == [.fixture(id: 1)])
        #expect(sut.uiState.approvedCount == 0)
        #expect(sut.uiState.actionErrorMessage == "요청을 처리하지 못했어요")
    }

    @Test func 늦게_온_목록은_처리_결과를_덮지_않는다() async {
        let repository = PendingPlaceRepositoryStub()
        let release = AsyncGate()
        repository.pending = { _ in
            await release.wait()
            return [.fixture(id: 1)]
        }
        let sut = PendingRequestViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        let load = sut.loadTask
        sut.approve(placeID: 1)
        await sut.actionTask?.value
        await release.open()
        await load?.value
        #expect(sut.uiState.requests.isEmpty)
    }

    @Test func 활동_문구는_받침에_맞는_조사를_붙인다() {
        #expect(MapLogText.message(for: activity(.placeAdded, place: "커피나무")) == "‘커피나무’ 를 추가했어요")
        #expect(MapLogText.message(for: activity(.placeRemoved, place: "달빛정원")) == "‘달빛정원’ 을 지도에서 삭제했어요")
        #expect(MapLogText.message(for: activity(.reviewCreated, place: "카페")) == "‘카페’ 에 댓글을 남겼어요")
        #expect(MapLogText.message(for: activity(.placeAdded, place: nil)) == "장소를 추가했어요")
        #expect(MapLogText.message(for: PendingPlace.fixture(id: 3)) == "‘장소 3’ 를 이 지도에 추가하고 싶어요")
        #expect(MapLogText.objectParticle("CAFE") == "를")
    }

    @Test func 요청은_커뮤니티_지도_방장과_관리자만_본다() {
        #expect(MapDetail.fixture(joined: true, type: .community, role: .owner).canReviewRequests)
        #expect(MapDetail.fixture(joined: true, type: .community, role: .admin).canReviewRequests)
        #expect(!MapDetail.fixture(joined: true, type: .community, role: .member).canReviewRequests)
        #expect(!MapDetail.fixture(joined: true, type: .private, role: .owner).canReviewRequests)
    }
}
