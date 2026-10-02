import Foundation
import Testing
@testable import MoaMap

@MainActor
struct PersonalMapAddViewModelTests {
    @Test func 추가하면_성공_안내를_남긴다() async {
        let repository = PersonalMapRepositoryStub()
        let sut = PersonalMapAddViewModel(repository: repository)
        sut.open(placeID: 3)
        sut.add()
        #expect(sut.uiState.adding)
        await sut.addTask?.value
        #expect(sut.uiState == PersonalMapAddUiState(placeID: 3, message: "나만의 지도에 추가했어요"))
    }

    @Test(arguments: [
        (NetworkError.server(code: "PLACE_010", statusCode: 409) as any Error, "이미 나만의 지도에 있는 장소예요"),
        (PersonalMapNotFoundError() as any Error, "나만의 지도를 찾지 못했어요"),
        (NetworkError.server(code: "COMMON_005", statusCode: 500) as any Error, "나만의 지도에 추가하지 못했어요")
    ])
    func 실패하면_원인에_맞는_안내를_빨갛게_남긴다(error: any Error, message: String) async {
        let repository = PersonalMapRepositoryStub()
        repository.add = { _ in throw error }
        let sut = PersonalMapAddViewModel(repository: repository)
        sut.open(placeID: 3)
        sut.add()
        await sut.addTask?.value
        #expect(sut.uiState == PersonalMapAddUiState(placeID: 3, message: message, failed: true))
    }

    @Test func 추가가_도는_동안_다시_눌러도_한_번만_보낸다() async {
        let repository = PersonalMapRepositoryStub()
        let release = AsyncGate()
        repository.add = { _ in await release.wait() }
        let sut = PersonalMapAddViewModel(repository: repository)
        sut.open(placeID: 3)
        sut.add()
        sut.add()
        await release.open()
        await sut.addTask?.value
        #expect(repository.addCalls == 1)
    }

    @Test func 다른_장소를_열면_앞_장소의_결과가_남지_않는다() async {
        let repository = PersonalMapRepositoryStub()
        let release = AsyncGate()
        repository.add = { _ in await release.wait() }
        let sut = PersonalMapAddViewModel(repository: repository)
        sut.open(placeID: 3)
        sut.add()
        let first = sut.addTask
        sut.open(placeID: 4)
        await release.open()
        await first?.value
        #expect(sut.uiState == PersonalMapAddUiState(placeID: 4))
    }

    @Test func 같은_장소를_다시_열면_안내를_그대로_둔다() async {
        let sut = PersonalMapAddViewModel(repository: PersonalMapRepositoryStub())
        sut.open(placeID: 3)
        sut.add()
        await sut.addTask?.value
        sut.open(placeID: 3)
        #expect(sut.uiState.message == "나만의 지도에 추가했어요")
        sut.close()
        #expect(sut.uiState == PersonalMapAddUiState())
    }
}
