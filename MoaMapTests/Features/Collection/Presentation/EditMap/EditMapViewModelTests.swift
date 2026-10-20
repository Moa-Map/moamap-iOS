import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MoaMap

@MainActor
struct EditMapViewModelTests {
    private let png = UploadImage(data: Data([1, 2, 3]), contentType: "image/png")

    private func map(imageURL: URL? = URL(string: "https://cdn.example.com/old.jpg")) -> MapDetail {
        MapDetail(
            id: 7, title: "성수 카페", description: "친구들과", imageURL: imageURL, ownerName: "모아",
            type: .community, role: .owner, tags: ["카페"], memberCount: 2, placeCount: 3,
            joined: true, personal: false, inviteCode: nil
        )
    }

    @Test func 원래_값으로_채우고_바뀐_게_없으면_저장할_수_없다() {
        let sut = EditMapViewModel(map: map(), repository: CollectionRepositoryStub())
        #expect(sut.uiState.name == "성수 카페")
        #expect(sut.uiState.description == "친구들과")
        #expect(sut.uiState.tags == ["카페"])
        #expect(!sut.uiState.canSave)
        sut.updateName("성수 카페 ")
        #expect(!sut.uiState.canSave)
        sut.updateTagInput("데이트")
        #expect(!sut.uiState.canSave)
        sut.updateTagInput("데이트 ")
        #expect(sut.uiState.canSave)
    }

    @Test func 이름을_비우면_저장할_수_없다() {
        let sut = EditMapViewModel(map: map(), repository: CollectionRepositoryStub())
        sut.updateDescription("새 설명")
        #expect(sut.uiState.canSave)
        sut.updateName("  ")
        #expect(!sut.uiState.canSave)
    }

    @Test func 사진을_바꾸지_않으면_원래_주소와_칩이_된_태그만_보낸다() async throws {
        let repository = CollectionRepositoryStub()
        let sut = EditMapViewModel(map: map(), repository: repository)
        sut.updateDescription("")
        sut.updateTagInput("데이트 성수")
        sut.save()
        #expect(sut.uiState.saving)
        try await sut.saveTask?.value
        #expect(repository.uploadedCovers.isEmpty)
        #expect(repository.updates.map(\.mapID) == [7])
        #expect(repository.updates.first?.update == MapUpdate(
            name: "성수 카페", description: "", tags: ["카페", "데이트"], imageURL: "https://cdn.example.com/old.jpg"
        ))
        #expect(sut.uiState.saved)
        #expect(!sut.uiState.saving)
    }

    @Test func 새_사진은_올린_주소로_보내고_저장만_실패하면_다시_올리지_않는다() async throws {
        let repository = CollectionRepositoryStub()
        repository.update = { _, _ in throw NetworkError.http(statusCode: 500) }
        let sut = EditMapViewModel(map: map(imageURL: nil), repository: repository)
        sut.selectImage(data: png.data, type: .png)
        sut.save()
        try await sut.saveTask?.value
        #expect(sut.uiState.errorMessage == EditMapViewModel.saveFailedMessage)
        #expect(!sut.uiState.saved)

        repository.update = { _, _ in }
        sut.save()
        try await sut.saveTask?.value
        #expect(repository.uploadedCovers.count == 1)
        #expect(repository.updates.map(\.update.imageURL) == ["https://cdn.example.com/cover.jpg", "https://cdn.example.com/cover.jpg"])
        #expect(sut.uiState.saved)
    }

    @Test func 권한을_잃었으면_권한_안내를_보여준다() async throws {
        let repository = CollectionRepositoryStub()
        repository.update = { _, _ in throw NetworkError.server(code: "MAP_003", statusCode: 403) }
        let sut = EditMapViewModel(map: map(), repository: repository)
        sut.updateName("새 이름")
        sut.save()
        try await sut.saveTask?.value
        #expect(sut.uiState.errorMessage == EditMapViewModel.noPermissionMessage)
    }

    @Test func 사진_업로드가_실패하면_정보를_저장하지_않는다() async throws {
        let repository = CollectionRepositoryStub()
        repository.uploadCover = { _ in throw NetworkError.connection(.notConnectedToInternet) }
        let sut = EditMapViewModel(map: map(), repository: repository)
        sut.selectImage(data: png.data, type: .png)
        sut.save()
        try await sut.saveTask?.value
        #expect(repository.updates.isEmpty)
        #expect(sut.uiState.errorMessage == "네트워크에 연결할 수 없어요")
    }

    @Test func 서버_값의_앞뒤_공백만으로는_바뀐_것으로_보지_않는다() {
        let original = MapDetail(
            id: 7, title: "성수 카페 ", description: "친구들과\n", imageURL: nil, ownerName: nil,
            type: .community, role: .owner, tags: [], memberCount: 1, placeCount: 0,
            joined: true, personal: false, inviteCode: nil
        )
        let sut = EditMapViewModel(map: original, repository: CollectionRepositoryStub())
        #expect(!sut.uiState.hasChanges)
    }
}
