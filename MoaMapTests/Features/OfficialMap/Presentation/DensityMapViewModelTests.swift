import Foundation
import Testing
@testable import MoaMap

private func area(_ code: String, _ level: CongestionLevel?) -> DensityArea {
    DensityArea(
        code: code, name: "지역 \(code)", latitude: 37.5, longitude: 127.0, boundary: nil,
        congestion: level.map {
            AreaCongestion(level: $0, message: nil, populationMin: nil, populationMax: nil, ageRates: [:], maleRate: nil, femaleRate: nil)
        }
    )
}

private struct StubError: Error {}

@MainActor
struct DensityMapViewModelTests {
    private let areas = [area("A", .busy), area("B", .relaxed), area("C", nil)]

    private func loaded() async -> (DensityMapViewModel, FootTrafficRepositoryStub) {
        let repository = FootTrafficRepositoryStub()
        repository.fetch = { [areas] in areas }
        let sut = DensityMapViewModel(repository: repository)
        sut.start()
        await sut.loadTask?.value
        return (sut, repository)
    }

    @Test func 처음_보이면_지역을_읽고_다시_보여도_또_읽지_않는다() async {
        let (sut, repository) = await loaded()
        #expect(sut.uiState.areas == areas)
        #expect(sut.uiState.visibleAreas == areas)
        sut.start()
        #expect(repository.fetchCalls == 1)
    }

    @Test func 못_받으면_안내를_띄우고_다시_시도하면_다시_읽는다() async {
        let repository = FootTrafficRepositoryStub()
        repository.fetch = { throw StubError() }
        let sut = DensityMapViewModel(repository: repository)
        sut.start()
        await sut.loadTask?.value
        #expect(sut.uiState.load == .failed("밀집도 정보를 불러오지 못했어요"))

        repository.fetch = { [areas] in areas }
        sut.retry()
        #expect(sut.uiState.load == .loading)
        await sut.loadTask?.value
        #expect(sut.uiState.load == .loaded)
    }

    @Test func 지역을_누르면_고르고_다시_누르면_푼다() async {
        let (sut, _) = await loaded()
        sut.selectArea("A")
        #expect(sut.uiState.selectedArea == areas[0])
        sut.selectArea("B")
        #expect(sut.uiState.selectedArea == areas[1])
        sut.selectArea("B")
        #expect(sut.uiState.selectedArea == nil)
    }

    @Test func 레벨을_고르면_그_레벨만_보이고_다시_고르면_전체로_돌아간다() async {
        let (sut, _) = await loaded()
        sut.selectLevel(.busy)
        #expect(sut.uiState.visibleAreas == [areas[0]])
        #expect(sut.visibleFeatures == [areas[0]].densityFeatures())
        sut.selectLevel(.busy)
        #expect(sut.uiState.filterLevel == nil)
        #expect(sut.uiState.visibleAreas == areas)
    }

    @Test func 보던_지역이_필터_밖으로_나가면_카드도_닫는다() async {
        let (sut, _) = await loaded()
        sut.selectArea("A")
        sut.selectLevel(.busy)
        #expect(sut.uiState.selectedArea == areas[0])
        sut.selectLevel(.relaxed)
        #expect(sut.uiState.selectedArea == nil)
        sut.selectLevel(nil)
        #expect(sut.uiState.selectedArea == nil)
    }
}
