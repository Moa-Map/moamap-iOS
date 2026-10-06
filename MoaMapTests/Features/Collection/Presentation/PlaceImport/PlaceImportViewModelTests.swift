import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MoaMap

@MainActor
struct PlaceImportViewModelTests {
    private let repository = PlaceImportRepositoryStub()
    private let collection = CollectionRepositoryStub()
    private let photo = UploadImage(data: Data([1, 2]), contentType: "image/png")

    private func sut(_ source: PlaceImportSource = .instagram, url: String = "https://www.instagram.com/p/A1/") -> PlaceImportViewModel {
        PlaceImportViewModel(source: source, url: url, importRepository: repository, collectionRepository: collection)
    }

    /// 장소를 받아 고른 상태까지 만든다.
    private func extracted(_ places: [ImportedPlace], select: [String] = []) async throws -> PlaceImportViewModel {
        repository.extractInstagram = { _ in places }
        let sut = sut()
        sut.startExtraction()
        try await sut.extractionTask?.value
        select.forEach(sut.togglePlace)
        return sut
    }

    // MARK: 추출

    @Test func 링크가_비어_있으면_검색하지_않는다() {
        let sut = sut(url: "  ")
        sut.startExtraction()
        #expect(sut.extractionTask == nil)
        #expect(!sut.uiState.canSearch)
    }

    @Test func 인스타그램은_고르지_않은_채로_시작한다() async throws {
        let sut = try await extracted([.fixture(id: "1"), .fixture(id: "2")])
        #expect(repository.extractedURLs == ["https://www.instagram.com/p/A1/"])
        #expect(sut.uiState.places.map(\.id) == ["1", "2"])
        #expect(sut.uiState.selectedPlaceIDs.isEmpty)
        #expect(!sut.uiState.canProceed)
    }

    @Test func 외부_지도는_등록할_수_있는_장소를_모두_고른_채로_시작한다() async throws {
        repository.extractMapShare = { _ in [.fixture(id: "1"), .fixture(id: "2", savable: false)] }
        let sut = sut(.mapShare, url: "https://naver.me/x")
        sut.startExtraction()
        #expect(sut.uiState.extraction == .loading)
        try await sut.extractionTask?.value
        #expect(sut.uiState.selectedPlaceIDs == ["1"])
    }

    @Test func 등록할_수_없는_장소는_고를_수_없다() async throws {
        let sut = try await extracted([.fixture(id: "1"), .fixture(id: "2", savable: false)], select: ["1", "2", "없음"])
        #expect(sut.uiState.selectedPlaceIDs == ["1"])
        sut.togglePlace("1")
        #expect(sut.uiState.selectedPlaceIDs.isEmpty)
    }

    @Test(arguments: [
        (PlaceExtractionError.captionBlocked as any Error, "비공개 게시물이라 장소를 가져올 수 없어요"),
        (NetworkError.server(code: "PLACE_020", statusCode: 400, message: "지원하지 않는 링크예요"), "지원하지 않는 링크예요"),
        (NetworkError.server(code: "COMMON_005", statusCode: 500), "장소를 가져오지 못했어요"),
        (NetworkError.connection(.notConnectedToInternet), "네트워크에 연결할 수 없어요")
    ])
    func 추출_실패는_원인에_맞게_안내한다(error: any Error, message: String) async throws {
        repository.extractInstagram = { _ in throw error }
        let sut = sut()
        sut.startExtraction()
        try await sut.extractionTask?.value
        #expect(sut.uiState.extraction == .idle)
        #expect(sut.uiState.errorMessage == message)
        sut.consumeError()
        #expect(sut.uiState.errorMessage == nil)
    }

    @Test func 재시도가_실패하면_보던_목록과_선택을_되돌린다() async throws {
        let places: [ImportedPlace] = [.fixture(id: "1"), .fixture(id: "2")]
        let sut = try await extracted(places, select: ["2"])
        repository.extractInstagram = { _ in throw NetworkError.http(statusCode: 500) }
        sut.startExtraction()
        #expect(sut.uiState.selectedPlaceIDs.isEmpty)
        try await sut.extractionTask?.value
        #expect(sut.uiState.extraction == .loaded(places))
        #expect(sut.uiState.selectedPlaceIDs == ["2"])
        #expect(sut.uiState.errorMessage == "장소를 가져오지 못했어요")
    }

    @Test func 재시도를_취소하면_보던_목록으로_돌아가고_늦은_결과는_버린다() async throws {
        let places: [ImportedPlace] = [.fixture(id: "1")]
        let sut = try await extracted(places, select: ["1"])
        let release = AsyncGate()
        repository.extractInstagram = { _ in await release.wait(); return [.fixture(id: "9")] }
        sut.startExtraction()
        let task = sut.extractionTask
        sut.cancelExtraction()
        #expect(sut.uiState.extraction == .loaded(places))
        #expect(sut.uiState.selectedPlaceIDs == ["1"])
        await release.open()
        await #expect(throws: CancellationError.self) { try await task?.value }
        #expect(sut.uiState.extraction == .loaded(places))
    }

    @Test func 처음_검색을_취소하면_비운다() async throws {
        let release = AsyncGate()
        repository.extractInstagram = { _ in await release.wait(); return [] }
        let sut = sut()
        sut.startExtraction()
        sut.cancelExtraction()
        #expect(sut.uiState.extraction == .idle)
        sut.cancelExtraction()
        await release.open()
    }

    // MARK: 편집

    @Test func 외부_지도의_메모를_편집_시작값으로_쓴다() async throws {
        let place = ImportedPlace.fixture(id: "1", description: "웨이팅 있음")
        let sut = try await extracted([place], select: ["1"])
        #expect(sut.uiState.edit(of: place).memo == "웨이팅 있음")
        sut.updateEditTags("1", tags: ["카페"])
        #expect(sut.uiState.edit(of: place) == PlaceEdit(tags: ["카페"], memo: "웨이팅 있음"))
        sut.updateEditMemo("1", memo: "")
        #expect(sut.uiState.selectedEntries.first?.edit.memo == "")
    }

    @Test func 사진은_5장까지_같은_사진_없이_붙인다() async throws {
        let place = ImportedPlace.fixture(id: "1")
        let sut = try await extracted([place], select: ["1"])
        sut.addEditPhoto("1", data: photo.data, type: .png)
        sut.addEditPhoto("1", data: photo.data, type: .png)
        for byte in 3...8 { sut.addEditPhoto("1", data: Data([UInt8(byte)]), type: .png) }
        #expect(sut.uiState.edit(of: place).photos.count == 5)
        sut.removeEditPhoto("1", at: 0)
        #expect(sut.uiState.edit(of: place).photos.count == 4)
        sut.addEditPhoto("1", data: nil, type: nil)
        #expect(sut.uiState.errorMessage == "사진을 불러오지 못했어요")
    }

    // MARK: 지도와 등록

    @Test func 프라이빗_지도를_읽고_실패하면_다시_읽는다() async throws {
        let maps = [MyMap(id: 1, title: "지도", imageURL: nil, memberCount: 1, placeCount: 0, official: false, personal: true)]
        collection.fetch = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = sut()
        sut.loadTargetMaps()
        try await sut.mapsTask?.value
        #expect(sut.uiState.targetMaps == .failed("지도 목록을 불러오지 못했어요"))
        collection.fetch = { _ in maps }
        sut.loadTargetMaps()
        #expect(sut.uiState.targetMaps == .loading)
        try await sut.mapsTask?.value
        #expect(sut.uiState.targetMaps == .loaded(maps))
        #expect(collection.calls == [.private, .private])
    }

    @Test func 고른_장소를_고른_지도에_편집값과_함께_등록한다() async throws {
        let sut = try await extracted([.fixture(id: "1"), .fixture(id: "2"), .fixture(id: "3")], select: ["3", "1"])
        sut.updateEditTags("1", tags: ["카페"])
        sut.addEditPhoto("1", data: photo.data, type: .png)
        #expect(!sut.uiState.canSave)
        sut.toggleMap(20)
        sut.toggleMap(10)
        sut.toggleMap(30)
        sut.toggleMap(30)
        sut.savePlaces()
        #expect(sut.uiState.saving)
        try await sut.saveTask?.value
        let call = try #require(repository.saveCalls.first)
        #expect(call.mapIDs == [20, 10])
        #expect(call.places.map(\.place.id) == ["1", "3"])
        #expect(call.places.first?.edit.tags == ["카페"])
        #expect(call.photoURLs == ["1": ["https://file/1"]])
        #expect(sut.uiState.saveResult == PlaceSaveResult(created: 2, duplicate: 0, failed: 0))
        #expect(!sut.uiState.saving)
    }

    @Test func 등록이_실패해_다시_누르면_올린_사진을_재사용하고_사진이_바뀌면_다시_올린다() async throws {
        let sut = try await extracted([.fixture(id: "1")], select: ["1"])
        sut.addEditPhoto("1", data: photo.data, type: .png)
        sut.toggleMap(1)
        repository.save = { _, _, _ in throw NetworkError.http(statusCode: 500) }
        sut.savePlaces()
        try await sut.saveTask?.value
        #expect(sut.uiState.errorMessage == "장소를 저장하지 못했어요")
        sut.savePlaces()
        try await sut.saveTask?.value
        #expect(repository.uploadCalls == 1)
        sut.addEditPhoto("1", data: Data([9]), type: .png)
        sut.savePlaces()
        try await sut.saveTask?.value
        #expect(repository.uploadCalls == 2)
    }

    @Test(arguments: [
        (PlaceSaveResult(created: 0, duplicate: 2, failed: 0), "이미 저장되어 있는 장소예요"),
        (PlaceSaveResult(created: 0, duplicate: 1, failed: 1), "장소를 저장하지 못했어요")
    ])
    func 하나도_등록되지_않으면_흐름을_닫지_않고_안내한다(result: PlaceSaveResult, message: String) async throws {
        let sut = try await extracted([.fixture(id: "1")], select: ["1"])
        sut.toggleMap(1)
        repository.save = { _, _, _ in result }
        sut.savePlaces()
        try await sut.saveTask?.value
        #expect(sut.uiState.saveResult == nil)
        #expect(sut.uiState.errorMessage == message)
        #expect(sut.uiState.canSave)
    }

    @Test(arguments: [
        (NetworkError.server(code: "PLACE_002", statusCode: 403, message: "지도 멤버만 등록할 수 있어요") as any Error, "지도 멤버만 등록할 수 있어요"),
        (ImageUploadError.tooLarge(maxFileSize: ImageUploadRules.maxPlacePhotoFileSize), "사진 크기는 5MB 이하여야 해요"),
        (NetworkError.connection(.timedOut), "네트워크에 연결할 수 없어요")
    ])
    func 등록_실패는_원인에_맞게_안내한다(error: any Error, message: String) async throws {
        let sut = try await extracted([.fixture(id: "1")], select: ["1"])
        sut.addEditPhoto("1", data: photo.data, type: .png)
        sut.toggleMap(1)
        repository.upload = { _ in throw error }
        sut.savePlaces()
        try await sut.saveTask?.value
        #expect(sut.uiState.errorMessage == message)
        #expect(repository.saveCalls.isEmpty)
    }

    @Test func 등록_중에는_다시_누를_수_없다() async throws {
        let sut = try await extracted([.fixture(id: "1")], select: ["1"])
        sut.toggleMap(1)
        let release = AsyncGate()
        repository.save = { _, places, _ in await release.wait(); return PlaceSaveResult(created: places.count, duplicate: 0, failed: 0) }
        sut.savePlaces()
        let task = sut.saveTask
        sut.savePlaces()
        #expect(!sut.uiState.canSave)
        await release.open()
        try await task?.value
        #expect(repository.saveCalls.count == 1)
    }
}
