import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MoaMap

@MainActor
struct PlaceEditViewModelTests {
    private let png = Data([0x89, 0x50, 0x4E, 0x47])
    private let a = URL(string: "https://file/a")!
    private let b = URL(string: "https://file/b")!

    @Test func 처음에는_장소의_사진_태그_메모로_채우고_바뀐_것이_없다() {
        let (sut, _, _) = makeSUT()
        #expect(sut.uiState.photoURLs == [a, b])
        #expect(sut.uiState.tags == ["카페"])
        #expect(sut.uiState.memo == "메모")
        #expect(!sut.uiState.changed)
    }

    @Test func 바뀐_것이_없으면_저장하지_않는다() async {
        let (sut, repository, _) = makeSUT()
        sut.save()
        await sut.saveTask?.value
        #expect(repository.updatedPlaces.isEmpty)
    }

    @Test func 새_사진은_올리고_남긴_사진과_함께_순서대로_보낸다() async {
        let (sut, repository, photos) = makeSUT()
        sut.removePhoto(at: 0)
        sut.addPhoto(data: png, type: .png)
        #expect(sut.uiState.photoCount == 2)
        sut.save()
        await sut.saveTask?.value
        #expect(photos.uploadCalls == 1)
        #expect(repository.updatedPlaces.map(\.photoURLs) == [["https://file/b", "https://file/0"]])
        // 손대지 않은 태그와 메모는 보내지 않는다.
        #expect(repository.updatedPlaces.map(\.tags) == [nil])
        #expect(repository.updatedPlaces.map(\.description) == [nil])
        #expect(sut.uiState.saved?.photoURLs == [b, URL(string: "https://file/0")!])
    }

    @Test func 사진을_모두_빼면_빈_목록을_보낸다() async {
        let (sut, repository, photos) = makeSUT()
        sut.removePhoto(at: 1)
        sut.removePhoto(at: 0)
        sut.save()
        await sut.saveTask?.value
        #expect(photos.uploadCalls == 0)
        #expect(repository.updatedPlaces.map(\.photoURLs) == [[]])
    }

    @Test func 새로_고른_사진은_서버_사진_뒤의_순서로_뺀다() {
        let (sut, _, _) = makeSUT()
        sut.addPhoto(data: png, type: .png)
        sut.removePhoto(at: 2)
        #expect(sut.uiState.newPhotos.isEmpty)
        #expect(sut.uiState.photoURLs == [a, b])
    }

    @Test func 사진은_서버_사진까지_다섯_장을_넘지_않는다() {
        let (sut, _, _) = makeSUT()
        for index in 0..<5 { sut.addPhoto(data: png + [UInt8(index)], type: .png) }
        #expect(sut.uiState.photoCount == AddPlaceUiState.maxPhotos)
        #expect(!sut.uiState.canAddPhoto)
    }

    @Test func 저장하면_고친_태그와_메모를_담은_장소를_넘긴다() async {
        let (sut, repository, _) = makeSUT()
        sut.updateTagInput("데이트\n")
        sut.removeTag("카페")
        sut.updateMemo("")
        sut.save()
        await sut.saveTask?.value
        #expect(repository.updatedPlaces.map(\.tags) == [["데이트"]])
        #expect(repository.updatedPlaces.map(\.description) == [""])
        // 사진은 그대로라 보내지 않는다. 앱이 읽지 못해 걸러 낸 서버 사진이 지워지면 안 된다.
        #expect(repository.updatedPlaces.map(\.photoURLs) == [nil])
        #expect(sut.uiState.saved?.tags == ["데이트"])
        #expect(sut.uiState.saved?.description == "")
        #expect(!sut.uiState.saving)
    }

    @Test func 저장만_실패하면_다시_눌러도_사진을_또_올리지_않는다() async {
        let (sut, repository, photos) = makeSUT()
        repository.editPlace = { _, _, _, _ in throw NetworkError.http(statusCode: 500) }
        sut.addPhoto(data: png, type: .png)
        sut.save()
        await sut.saveTask?.value
        #expect(sut.uiState.errorMessage == "장소 정보를 수정하지 못했어요")
        #expect(sut.uiState.saved == nil)
        #expect(sut.uiState.changed)

        repository.editPlace = { _, _, _, _ in }
        sut.save()
        await sut.saveTask?.value
        #expect(photos.uploadCalls == 1)
        #expect(repository.updatedPlaces.last?.photoURLs == ["https://file/a", "https://file/b", "https://file/0"])
    }

    @Test func 올린_사진_주소를_읽지_못하면_고른_사진을_남기고_실패로_알린다() async {
        let (sut, repository, photos) = makeSUT()
        photos.upload = { _ in [""] }
        sut.addPhoto(data: png, type: .png)
        sut.save()
        await sut.saveTask?.value
        #expect(repository.updatedPlaces.isEmpty)
        #expect(sut.uiState.newPhotos.count == 1)
        #expect(sut.uiState.photoURLs == [a, b])
        #expect(sut.uiState.errorMessage == "장소 정보를 수정하지 못했어요")
    }

    @Test func 사진을_올리지_못하면_장소는_고치지_않는다() async {
        let (sut, repository, photos) = makeSUT()
        photos.upload = { _ in throw NetworkError.http(statusCode: 500) }
        sut.addPhoto(data: png, type: .png)
        sut.save()
        await sut.saveTask?.value
        #expect(repository.updatedPlaces.isEmpty)
        #expect(sut.uiState.newPhotos.count == 1)
        #expect(sut.uiState.errorMessage == "장소 정보를 수정하지 못했어요")
    }

    private func makeSUT() -> (PlaceEditViewModel, MapDetailRepositoryStub, PlaceAddRepositoryStub) {
        var place = MapPlace.fixture(id: 1)
        place.photoURLs = [a, b]
        place.tags = ["카페"]
        place.description = "메모"
        let repository = MapDetailRepositoryStub()
        let photos = PlaceAddRepositoryStub()
        let sut = PlaceEditViewModel(place: place, mapID: 7, repository: repository, photoRepository: photos)
        return (sut, repository, photos)
    }
}
