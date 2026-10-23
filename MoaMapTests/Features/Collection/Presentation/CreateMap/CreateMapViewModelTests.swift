import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MoaMap

@MainActor
struct CreateMapViewModelTests {
    private let png = UploadImage(data: Data([1, 2, 3]), contentType: "image/png")
    private let importRepository = PlaceImportRepositoryStub()

    private func makeSUT(_ repository: CollectionRepositoryStub = CollectionRepositoryStub()) -> CreateMapViewModel {
        CreateMapViewModel(repository: repository, importRepository: importRepository)
    }

    private func filled(_ repository: CollectionRepositoryStub, visibility: MapVisibility = .public) -> CreateMapViewModel {
        let sut = makeSUT(repository)
        sut.updateName("성수 카페")
        sut.selectVisibility(visibility)
        return sut
    }

    @Test func 이름과_공개_범위가_있어야_만들_수_있다() {
        let sut = makeSUT()
        #expect(!sut.uiState.canSubmit)
        sut.updateName("   ")
        sut.selectVisibility(.private)
        #expect(!sut.uiState.canSubmit)
        sut.updateName("지도")
        #expect(sut.uiState.canSubmit)
    }

    @Test func 이름과_설명은_서버_제한_길이에서_자른다() {
        let sut = makeSUT()
        sut.updateName(String(repeating: "가", count: 101))
        sut.updateDescription(String(repeating: "나", count: 501))
        #expect(sut.uiState.name.count == 100)
        #expect(sut.uiState.description.count == 500)
    }

    @Test func 줄바꿈이_들어와야_태그로_확정하고_공백은_태그_안에_남긴다() {
        let sut = makeSUT()
        sut.updateTagInput("카페 ")
        #expect(sut.uiState.tags.isEmpty)
        #expect(sut.uiState.tagInput == "카페 ")
        sut.updateTagInput("성수 카페\n")
        #expect(sut.uiState.tags == ["성수 카페"])
        #expect(sut.uiState.tagInput == "")
        sut.updateTagInput("데이트\n 맛집 \n맛")
        #expect(sut.uiState.tags == ["성수 카페", "데이트", "맛집"])
        #expect(sut.uiState.tagInput == "맛")
        sut.removeTag("데이트")
        #expect(sut.uiState.tags == ["성수 카페", "맛집"])
    }

    @Test func 태그는_30자에서_자르고_빈_값은_담지_않는다() {
        let sut = makeSUT()
        sut.updateTagInput(String(repeating: "a", count: 31))
        #expect(sut.uiState.tagInput.count == 30)
        sut.updateTagInput("   \n")
        #expect(sut.uiState.tags.isEmpty)
    }

    @Test func 고른_사진을_지울_수_있다() {
        let sut = makeSUT()
        sut.selectImage(data: png.data, type: .png)
        #expect(sut.uiState.pickedImage != nil)
        sut.removeImage()
        #expect(sut.uiState.pickedImage == nil)
    }

    @Test func 허용되지_않는_사진은_고르지_않고_안내한다() {
        let sut = makeSUT()
        sut.selectImage(data: Data("x".utf8), type: .heic)
        #expect(sut.uiState.pickedImage == nil)
        #expect(sut.uiState.errorMessage == "사진을 불러오지 못했어요")
        sut.consumeError()
        sut.showImageLoadFailure()
        #expect(sut.uiState.errorMessage == "사진을 불러오지 못했어요")
    }

    @Test func 커버를_올리고_칩이_된_태그만_담아_공개_지도를_만든다() async throws {
        let repository = CollectionRepositoryStub()
        repository.create = { _ in CreatedMap(id: 7, inviteCode: nil) }
        let sut = filled(repository)
        sut.updateDescription("설명")
        sut.updateTagInput("카페\n성수")
        sut.selectImage(data: png.data, type: .png)
        sut.submit()
        #expect(sut.uiState.isSubmitting)
        try await sut.submitTask?.value
        #expect(repository.uploadedCovers == [png])
        #expect(repository.createdMaps == [NewMap(
            name: "성수 카페", description: "설명", visibility: .public,
            tags: ["카페"], imageURL: "https://cdn.example.com/cover.jpg"
        )])
        #expect(sut.uiState.tags == ["카페"])
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

    @Test func 프라이빗_지도는_초대_코드를_넘기며_끝낸다() async throws {
        let repository = CollectionRepositoryStub()
        repository.create = { _ in CreatedMap(id: 3, inviteCode: "VH4YXZ") }
        let sut = filled(repository, visibility: .private)
        sut.submit()
        try await sut.submitTask?.value
        #expect(sut.uiState.submit == .done(mapID: 3, inviteCode: "VH4YXZ"))
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
        sut.updateTagInput("카페\n")
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

    // MARK: 외부 지도에서 불러온 장소

    private func imported(_ id: String, photo: Bool = false) -> EditedPlace {
        EditedPlace(place: .fixture(id: id), edit: PlaceEdit(memo: "메모 \(id)", photos: photo ? [png] : []))
    }

    @Test func 불러온_장소는_지도를_만든_뒤_사진을_올리고_그_지도에_등록한다() async throws {
        let repository = CollectionRepositoryStub()
        var calls: [String] = []
        repository.create = { _ in calls.append("create"); return CreatedMap(id: 9, inviteCode: nil) }
        importRepository.upload = { _ in calls.append("upload"); return ["2": ["https://file/2"]] }
        importRepository.save = { _, places, _ in
            calls.append("save")
            return PlaceSaveResult(created: places.count, duplicate: 0, failed: 0)
        }
        let sut = filled(repository)
        let places = [imported("1"), imported("2", photo: true)]
        sut.setImportedPlaces(places)
        sut.submit()
        try await sut.submitTask?.value
        #expect(calls == ["create", "upload", "save"])
        #expect(importRepository.uploadMapIDs == [9])
        #expect(importRepository.saveCalls.map(\.mapIDs) == [[9]])
        #expect(importRepository.saveCalls.first?.places == places)
        #expect(importRepository.saveCalls.first?.photoURLs == ["2": ["https://file/2"]])
        #expect(sut.uiState.placeSaveNotice == nil)
        #expect(sut.uiState.submit == .done(mapID: 9))
    }

    @Test func 불러온_장소에_사진이_없으면_올리지_않고_등록한다() async throws {
        let sut = filled(CollectionRepositoryStub())
        sut.setImportedPlaces([imported("1")])
        sut.submit()
        try await sut.submitTask?.value
        #expect(importRepository.uploadCalls == 0)
        #expect(importRepository.saveCalls.count == 1)
    }

    @Test func 불러온_장소가_없으면_지도만_만든다() async throws {
        let repository = CollectionRepositoryStub()
        let sut = filled(repository)
        sut.submit()
        try await sut.submitTask?.value
        #expect(repository.createdMaps.count == 1)
        #expect(importRepository.uploadCalls == 0)
        #expect(importRepository.saveCalls.isEmpty)
        #expect(sut.uiState.submit == .done(mapID: 1))
    }

    @Test func 지도_생성이_실패하면_장소를_등록하지_않는다() async throws {
        let repository = CollectionRepositoryStub()
        repository.create = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = filled(repository)
        sut.setImportedPlaces([imported("1", photo: true)])
        sut.submit()
        try await sut.submitTask?.value
        #expect(importRepository.uploadCalls == 0)
        #expect(importRepository.saveCalls.isEmpty)
        #expect(sut.uiState.submit == .idle)
        #expect(sut.uiState.errorMessage == "지도를 만들지 못했어요")
        #expect(sut.uiState.importedPlaces.count == 1)
    }

    enum PlaceSaveFailure: CaseIterable { case upload, save, noneCreated, partial }

    @Test(arguments: PlaceSaveFailure.allCases)
    func 장소를_다_넣지_못해도_지도는_두고_안내한_뒤_초대_코드로_이어간다(failure: PlaceSaveFailure) async throws {
        let repository = CollectionRepositoryStub()
        repository.create = { _ in CreatedMap(id: 4, inviteCode: "VH4YXZ") }
        switch failure {
        case .upload: importRepository.upload = { _ in throw NetworkError.http(statusCode: 500) }
        case .save: importRepository.save = { _, _, _ in throw NetworkError.connection(.timedOut) }
        case .noneCreated: importRepository.save = { _, _, _ in PlaceSaveResult(created: 0, duplicate: 0, failed: 2) }
        case .partial: importRepository.save = { _, _, _ in PlaceSaveResult(created: 0, duplicate: 1, failed: 1) }
        }
        let sut = filled(repository, visibility: .private)
        sut.setImportedPlaces([imported("1", photo: true), imported("2")])
        sut.submit()
        try await sut.submitTask?.value
        #expect(repository.createdMaps.count == 1)
        #expect(sut.uiState.placeSaveNotice == (failure == .partial ? "일부 장소를 못 넣었어요" : "불러온 장소를 넣지 못했어요"))
        #expect(sut.uiState.errorMessage == nil)
        #expect(sut.uiState.submit == .done(mapID: 4, inviteCode: "VH4YXZ"))
    }

    @Test func 이미_들어_있던_장소는_넣은_것으로_보고_안내하지_않는다() async throws {
        importRepository.save = { _, _, _ in PlaceSaveResult(created: 1, duplicate: 1, failed: 0) }
        let sut = filled(CollectionRepositoryStub())
        sut.setImportedPlaces([imported("1"), imported("1")])
        sut.submit()
        try await sut.submitTask?.value
        #expect(sut.uiState.placeSaveNotice == nil)
    }

    @Test func 다시_불러오면_앞의_결과를_바꾼다() async throws {
        let sut = filled(CollectionRepositoryStub())
        sut.setImportedPlaces([imported("1"), imported("2")])
        sut.setImportedPlaces([imported("3")])
        #expect(sut.uiState.importedPlaces == [imported("3")])
        sut.submit()
        try await sut.submitTask?.value
        #expect(importRepository.saveCalls.first?.places == [imported("3")])
    }
}
