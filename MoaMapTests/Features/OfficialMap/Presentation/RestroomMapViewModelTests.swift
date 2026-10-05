import Foundation
import Testing
@testable import MoaMap

private let bounds = ViewportBounds(south: 37.49, west: 127.01, north: 37.51, east: 127.03)
private let moved = ViewportBounds(south: 37.59, west: 127.11, north: 37.61, east: 127.13)
private let restroom = RestroomMarker(id: 1, name: "명달근린공원", latitude: 37.5, longitude: 127.02, category: "공중화장실")
private struct StubError: Error {}

@MainActor
struct RestroomMapViewModelTests {
    @Test func 카메라가_멈추면_보이는_범위의_화장실을_읽는다() async {
        let repository = RestroomRepositoryStub()
        repository.fetch = { _ in RestroomMarkers(restrooms: [restroom], truncated: true) }
        let sut = RestroomMapViewModel(repository: repository)
        sut.onCameraIdle(bounds)
        await sut.loadTask?.value
        #expect(repository.requests == [bounds])
        #expect(sut.uiState.restrooms == [restroom])
        #expect(sut.uiState.truncated)
        #expect(!sut.uiState.loadFailed)
    }

    @Test func 같은_범위에서_다시_멈추면_읽지_않는다() async {
        let repository = RestroomRepositoryStub()
        let sut = RestroomMapViewModel(repository: repository)
        sut.onCameraIdle(bounds)
        await sut.loadTask?.value
        sut.onCameraIdle(bounds)
        #expect(repository.requests.count == 1)
    }

    @Test func 새_범위로_멈추면_앞선_조회를_버린다() async {
        let repository = RestroomRepositoryStub()
        let release = AsyncGate()
        repository.fetch = { requested in
            if requested == bounds { await release.wait() }
            return RestroomMarkers(restrooms: requested == bounds ? [restroom] : [], truncated: false)
        }
        let sut = RestroomMapViewModel(repository: repository)
        sut.onCameraIdle(bounds)
        let first = sut.loadTask
        sut.onCameraIdle(moved)
        await sut.loadTask?.value
        await release.open()
        await first?.value
        #expect(sut.uiState.restrooms.isEmpty)
    }

    @Test func 못_읽으면_실패를_표시하고_같은_자리에서도_다시_읽는다() async {
        let repository = RestroomRepositoryStub()
        repository.fetch = { _ in RestroomMarkers(restrooms: [restroom], truncated: false) }
        let sut = RestroomMapViewModel(repository: repository)
        sut.onCameraIdle(bounds)
        await sut.loadTask?.value

        repository.fetch = { _ in throw StubError() }
        sut.onCameraIdle(moved)
        await sut.loadTask?.value
        #expect(sut.uiState.loadFailed)
        #expect(sut.uiState.restrooms == [restroom])

        repository.fetch = { _ in RestroomMarkers(restrooms: [], truncated: false) }
        sut.onCameraIdle(moved)
        await sut.loadTask?.value
        #expect(repository.requests == [bounds, moved, moved])
        #expect(!sut.uiState.loadFailed)
    }

    @Test func 마커를_누르면_상세를_읽고_빈_곳을_누르면_닫는다() async {
        let repository = RestroomRepositoryStub()
        repository.fetch = { _ in RestroomMarkers(restrooms: [restroom], truncated: false) }
        let sut = RestroomMapViewModel(repository: repository)
        sut.onCameraIdle(bounds)
        await sut.loadTask?.value

        sut.selectRestroom(id: 1)
        #expect(sut.uiState.selected == restroom)
        #expect(sut.uiState.detail == .loading)
        await sut.detailTask?.value
        #expect(sut.uiState.detail == .loaded(.stub(id: 1)))

        sut.clearSelection()
        #expect(sut.uiState.selected == nil)
        #expect(sut.uiState.detail == nil)
    }

    @Test func 같은_화장실을_다시_누르면_실패했던_상세만_다시_읽는다() async {
        let repository = RestroomRepositoryStub()
        repository.fetch = { _ in RestroomMarkers(restrooms: [restroom], truncated: false) }
        let sut = RestroomMapViewModel(repository: repository)
        sut.onCameraIdle(bounds)
        await sut.loadTask?.value
        sut.selectRestroom(id: 1)
        await sut.detailTask?.value
        sut.selectRestroom(id: 1)
        #expect(repository.detailRequests == [1])

        repository.detail = { _ in throw StubError() }
        sut.clearSelection()
        sut.selectRestroom(id: 1)
        await sut.detailTask?.value
        #expect(sut.uiState.detail == .failed)
        repository.detail = { id in .stub(id: id) }
        sut.selectRestroom(id: 1)
        await sut.detailTask?.value
        #expect(sut.uiState.detail == .loaded(.stub(id: 1)))
    }

    @Test func 지도를_옮겨_목록에서_빠져도_고른_카드는_남는다() async {
        let repository = RestroomRepositoryStub()
        repository.fetch = { requested in RestroomMarkers(restrooms: requested == bounds ? [restroom] : [], truncated: false) }
        let sut = RestroomMapViewModel(repository: repository)
        sut.onCameraIdle(bounds)
        await sut.loadTask?.value
        sut.selectRestroom(id: 1)
        sut.onCameraIdle(moved)
        await sut.loadTask?.value
        #expect(sut.uiState.selected == restroom)
    }
}

struct RestroomInfoRowsTests {
    @Test func 다_있으면_항목_순서대로_줄을_만든다() {
        let rows = RestroomDetail.stub(
            address: "서울특별시 중구 세종대로 지하 101", openHours: "정시", openHoursDetail: "05:00~24:00",
            maleToilet: 6, maleUrinal: 5, maleDisabledToilet: 1, femaleToilet: 15, femaleDisabledToilet: 1,
            diaperTable: true, emergencyBell: true, entranceCctv: true, managerOrg: "서울교통공사", phone: "02-6110-1321"
        ).infoRows
        #expect(rows == [
            RestroomInfoRow(label: "주소", value: "서울특별시 중구 세종대로 지하 101"),
            RestroomInfoRow(label: "개방시간", value: "정시 · 05:00~24:00"),
            RestroomInfoRow(label: "남자", value: "대변기 6 · 소변기 5"),
            RestroomInfoRow(label: "여자", value: "대변기 15"),
            RestroomInfoRow(label: "장애인용", value: "남 대변기 1 · 여 대변기 1"),
            RestroomInfoRow(label: "편의시설", value: "기저귀 교환대 · 비상벨 · 입구 CCTV"),
            RestroomInfoRow(label: "관리기관", value: "서울교통공사 · 02-6110-1321")
        ])
    }

    @Test func 영인_칸과_없는_시설은_빼고_남는_게_없는_항목은_줄째_뺀다() {
        #expect(RestroomDetail.stub(maleUrinal: 2, phone: "02-000-0000").infoRows == [
            RestroomInfoRow(label: "남자", value: "소변기 2"),
            RestroomInfoRow(label: "관리기관", value: "02-000-0000")
        ])
    }
}
