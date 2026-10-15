import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MoaMap

@MainActor
struct MapPostCreateViewModelTests {
    private let photoData = Data([1, 2, 3])

    private func viewModel(_ repository: MapPostRepositoryStub = MapPostRepositoryStub()) -> MapPostCreateViewModel {
        MapPostCreateViewModel(mapID: 10, repository: repository)
    }

    @Test(arguments: ["", "  \n "])
    func 본문이_비어_있으면_올릴_수_없다(content: String) {
        let repository = MapPostRepositoryStub()
        let sut = viewModel(repository)
        sut.updateContent(content)
        #expect(!sut.uiState.canSubmit)
        sut.submit()
        #expect(sut.submitTask == nil)
        #expect(repository.created.isEmpty)
    }

    @Test func 본문은_한도까지만_받는다() {
        let sut = viewModel()
        sut.updateContent(String(repeating: "가", count: MapPostCreateUiState.maxContentLength + 5))
        #expect(sut.uiState.content.count == MapPostCreateUiState.maxContentLength)
    }

    @Test func 장소는_한_곳만_태그하고_빼면_다시_고를_수_있다() {
        let sut = viewModel()
        sut.addPlace(.fixture(id: 1))
        sut.addPlace(.fixture(id: 2))
        #expect(sut.uiState.places == [SelectedPostPlace(id: 1, name: "장소 1", address: "")])
        #expect(!sut.uiState.canAddPlace)
        sut.removePlace(id: 1)
        sut.addPlace(.fixture(id: 2))
        #expect(sut.uiState.places.map(\.id) == [2])
    }

    @Test func 사진은_한_장까지만_받는다() {
        let sut = viewModel()
        sut.addPhoto(data: photoData, type: .png)
        sut.addPhoto(data: Data([4]), type: .png)
        #expect(sut.uiState.photos == [UploadImage(data: photoData, contentType: "image/png")])
        #expect(!sut.uiState.canAddPhoto)
    }

    @Test func 읽지_못한_사진은_안내만_남긴다() {
        let sut = viewModel()
        sut.addPhoto(data: nil, type: nil)
        #expect(sut.uiState.photos.isEmpty)
        #expect(sut.uiState.errorMessage == ImageUploadError.unreadable.userMessage)
    }

    @Test func 사진을_먼저_올리고_받은_주소로_게시물을_올린다() async {
        let repository = MapPostRepositoryStub()
        let sut = viewModel(repository)
        sut.updateContent("  성수 카페 다녀왔어요 ")
        sut.addPhoto(data: photoData, type: .png)
        sut.addPlace(.fixture(id: 5))
        sut.submit()
        #expect(sut.uiState.submitting)
        await sut.submitTask?.value
        #expect(repository.uploadCalls.count == 1)
        #expect(repository.created == [NewMapPost(
            content: "성수 카페 다녀왔어요",
            photoURLs: ["https://cdn/0.jpg"],
            placeTags: [MapPostPlaceTag(placeID: 5, name: "장소 5")]
        )])
    }

    @Test func 사진이_없으면_올리지_않고_바로_게시물을_올린다() async {
        let repository = MapPostRepositoryStub()
        let sut = viewModel(repository)
        sut.updateContent("글")
        sut.submit()
        await sut.submitTask?.value
        #expect(repository.uploadCalls.isEmpty)
        #expect(repository.created.map(\.photoURLs) == [[]])
    }

    @Test func 올리고_나면_폼을_비우고_성공을_알린다() async {
        let sut = viewModel()
        sut.updateContent("글")
        sut.addPlace(.fixture(id: 1))
        sut.submit()
        await sut.submitTask?.value
        #expect(sut.uiState == MapPostCreateUiState(postedCount: 1))
    }

    @Test(arguments: [
        (ImageUploadError.tooLarge(maxFileSize: 5 * 1024 * 1024) as any Error, "사진 크기는 5MB 이하여야 해요"),
        (NetworkError.http(statusCode: 500) as any Error, "사진을 올리지 못했어요"),
        (NetworkError.connection(.notConnectedToInternet) as any Error, "네트워크에 연결할 수 없어요")
    ])
    func 사진이_걸리면_이유를_보여주고_게시물은_올리지_않는다(error: any Error, message: String) async {
        let repository = MapPostRepositoryStub()
        repository.upload = { _ in throw error }
        let sut = viewModel(repository)
        sut.updateContent("글")
        sut.addPhoto(data: photoData, type: .png)
        sut.submit()
        await sut.submitTask?.value
        #expect(repository.created.isEmpty)
        #expect(sut.uiState.errorMessage == message)
        #expect(!sut.uiState.submitting)
        #expect(sut.uiState.content == "글")
    }

    @Test func 작성만_실패했으면_다시_누를_때_사진을_또_올리지_않는다() async {
        let repository = MapPostRepositoryStub()
        repository.create = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = viewModel(repository)
        sut.updateContent("글")
        sut.addPhoto(data: photoData, type: .png)
        sut.submit()
        await sut.submitTask?.value
        #expect(sut.uiState.errorMessage == MapPostCreateViewModel.createFailedMessage)
        #expect(sut.uiState.uploadedPhotoURLs == ["https://cdn/0.jpg"])

        repository.create = { _ in }
        sut.submit()
        await sut.submitTask?.value
        #expect(repository.uploadCalls.count == 1)
        #expect(repository.created.map(\.photoURLs) == [["https://cdn/0.jpg"], ["https://cdn/0.jpg"]])
        #expect(sut.uiState.postedCount == 1)
    }

    @Test func 사진을_바꾸면_앞서_올린_주소는_버린다() async {
        let repository = MapPostRepositoryStub()
        repository.create = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = viewModel(repository)
        sut.updateContent("글")
        sut.addPhoto(data: photoData, type: .png)
        sut.submit()
        await sut.submitTask?.value
        sut.removePhoto(at: 0)
        #expect(sut.uiState.uploadedPhotoURLs.isEmpty)
    }

    @Test func 다시_열어_비워도_성공_횟수는_남긴다() async {
        let sut = viewModel()
        sut.updateContent("글")
        sut.submit()
        await sut.submitTask?.value
        sut.updateContent("쓰다 만 글")
        sut.reset()
        #expect(sut.uiState == MapPostCreateUiState(postedCount: 1))
    }
}
