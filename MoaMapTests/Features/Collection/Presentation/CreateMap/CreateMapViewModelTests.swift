import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MoaMap

@MainActor
struct CreateMapViewModelTests {
    private let png = UploadImage(data: Data([1, 2, 3]), contentType: "image/png")

    private func filled(_ repository: CollectionRepositoryStub, visibility: MapVisibility = .public) -> CreateMapViewModel {
        let sut = CreateMapViewModel(repository: repository)
        sut.updateName("성수 카페")
        sut.selectVisibility(visibility)
        return sut
    }

    @Test func 이름과_공개_범위가_있어야_만들_수_있다() {
        let sut = CreateMapViewModel(repository: CollectionRepositoryStub())
        #expect(!sut.uiState.canSubmit)
        sut.updateName("   ")
        sut.selectVisibility(.private)
        #expect(!sut.uiState.canSubmit)
        sut.updateName("지도")
        #expect(sut.uiState.canSubmit)
    }

    @Test func 이름과_설명은_서버_제한_길이에서_자른다() {
        let sut = CreateMapViewModel(repository: CollectionRepositoryStub())
        sut.updateName(String(repeating: "가", count: 101))
        sut.updateDescription(String(repeating: "나", count: 501))
        #expect(sut.uiState.name.count == 100)
        #expect(sut.uiState.description.count == 500)
    }

    @Test func 공백이나_줄바꿈이_들어오면_태그로_확정한다() {
        let sut = CreateMapViewModel(repository: CollectionRepositoryStub())
        sut.updateTagInput("카페")
        #expect(sut.uiState.tags.isEmpty)
        sut.updateTagInput("카페 ")
        #expect(sut.uiState.tags == ["카페"])
        #expect(sut.uiState.tagInput == "")
        sut.updateTagInput("성수\n카페  데이트 맛")
        #expect(sut.uiState.tags == ["카페", "성수", "데이트"])
        #expect(sut.uiState.tagInput == "맛")
        sut.commitTag()
        #expect(sut.uiState.tags == ["카페", "성수", "데이트", "맛"])
        sut.removeTag("성수")
        #expect(sut.uiState.tags == ["카페", "데이트", "맛"])
    }

    @Test func 태그는_30자에서_자르고_빈_값은_담지_않는다() {
        let sut = CreateMapViewModel(repository: CollectionRepositoryStub())
        sut.updateTagInput(String(repeating: "a", count: 31))
        #expect(sut.uiState.tagInput.count == 30)
        sut.updateTagInput("   ")
        sut.commitTag()
        #expect(sut.uiState.tags.isEmpty)
    }

    @Test func 허용되지_않는_사진은_고르지_않고_안내한다() {
        let sut = CreateMapViewModel(repository: CollectionRepositoryStub())
        sut.selectImage(data: Data(count: ImageUploadRules.maxImageFileSize + 1), type: .png)
        #expect(sut.uiState.pickedImage == nil)
        #expect(sut.uiState.errorMessage == "사진 크기는 10MB 이하여야 해요")
        sut.consumeError()
        sut.showImageLoadFailure()
        #expect(sut.uiState.errorMessage == "사진을 불러오지 못했어요")
    }

    @Test func 커버를_올리고_입력중인_태그까지_담아_공개_지도를_만든다() async throws {
        let repository = CollectionRepositoryStub()
        repository.create = { _ in CreatedMap(id: 7, inviteCode: nil) }
        let sut = filled(repository)
        sut.updateDescription("설명")
        sut.updateTagInput("카페 성수")
        sut.selectImage(data: png.data, type: .png)
        sut.submit()
        #expect(sut.uiState.isSubmitting)
        try await sut.submitTask?.value
        #expect(repository.uploadedCovers == [png])
        #expect(repository.createdMaps == [NewMap(
            name: "성수 카페", description: "설명", visibility: .public,
            tags: ["카페", "성수"], imageURL: "https://cdn.example.com/cover.jpg"
        )])
        #expect(sut.uiState.tags == ["카페", "성수"])
        #expect(sut.uiState.submit == .done(mapID: 7))
    }

    @Test func 사진이_없으면_올리지_않는다() async throws {
        let repository = CollectionRepositoryStub()
        let sut = filled(repository)
        sut.submit()
        try await sut.submitTask?.value
        #expect(repository.uploadedCovers.isEmpty)
        #expect(repository.createdMaps.first?.imageURL == nil)
    }

    @Test func 프라이빗_지도는_초대_코드를_보여준_뒤_끝낸다() async throws {
        let repository = CollectionRepositoryStub()
        repository.create = { _ in CreatedMap(id: 3, inviteCode: "VH4YXZ") }
        let sut = filled(repository, visibility: .private)
        sut.submit()
        try await sut.submitTask?.value
        #expect(sut.uiState.submit == .showingInviteCode(mapID: 3, inviteCode: "VH4YXZ"))
        sut.dismissInviteCode()
        #expect(sut.uiState.submit == .done(mapID: 3))
    }

    @Test(arguments: [
        (NetworkError.connection(.notConnectedToInternet), "네트워크에 연결할 수 없어요"),
        (NetworkError.http(statusCode: 500), "사진을 올리지 못했어요")
    ])
    func 커버_업로드가_실패하면_지도를_만들지_않는다(error: NetworkError, message: String) async throws {
        let repository = CollectionRepositoryStub()
        repository.uploadCover = { _ in throw error }
        let sut = filled(repository)
        sut.selectImage(data: png.data, type: .png)
        sut.submit()
        try await sut.submitTask?.value
        #expect(repository.createdMaps.isEmpty)
        #expect(sut.uiState.submit == .idle)
        #expect(sut.uiState.errorMessage == message)
        #expect(sut.uiState.name == "성수 카페")
    }

    @Test(arguments: [
        (NetworkError.connection(.timedOut), "네트워크에 연결할 수 없어요"),
        (NetworkError.server(code: "COMMON_005", statusCode: 500), "지도를 만들지 못했어요")
    ])
    func 생성_실패는_서버_원문_대신_안내하고_입력값을_남긴다(error: NetworkError, message: String) async throws {
        let repository = CollectionRepositoryStub()
        repository.create = { _ in throw error }
        let sut = filled(repository)
        sut.updateTagInput("카페 ")
        sut.submit()
        try await sut.submitTask?.value
        #expect(sut.uiState.submit == .idle)
        #expect(sut.uiState.errorMessage == message)
        #expect(sut.uiState.tags == ["카페"])
        #expect(sut.uiState.canSubmit)
    }

    @Test func 생성만_실패해_다시_누르면_같은_사진을_다시_올리지_않는다() async throws {
        let repository = CollectionRepositoryStub()
        repository.create = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = filled(repository)
        sut.selectImage(data: png.data, type: .png)
        sut.submit()
        try await sut.submitTask?.value
        repository.create = { _ in CreatedMap(id: 1, inviteCode: nil) }
        sut.submit()
        try await sut.submitTask?.value
        #expect(repository.uploadedCovers.count == 1)
        #expect(repository.createdMaps.map(\.imageURL) == ["https://cdn.example.com/cover.jpg", "https://cdn.example.com/cover.jpg"])

        sut.selectImage(data: png.data, type: .png)
        sut.submit()
        try await sut.submitTask?.value
        #expect(repository.uploadedCovers.count == 2)
    }

    @Test func 제출_중에는_사진_변경과_재제출을_막는다() async throws {
        let repository = CollectionRepositoryStub()
        let release = AsyncGate()
        repository.create = { _ in await release.wait(); return CreatedMap(id: 1, inviteCode: nil) }
        let sut = filled(repository)
        sut.submit()
        let task = sut.submitTask
        sut.selectImage(data: png.data, type: .png)
        sut.submit()
        #expect(sut.uiState.pickedImage == nil)
        await release.open()
        try await task?.value
        #expect(repository.createdMaps.count == 1)
    }
}
