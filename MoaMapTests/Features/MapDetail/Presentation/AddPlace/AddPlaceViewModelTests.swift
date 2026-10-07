import Foundation
import Testing
import UniformTypeIdentifiers
@testable import MoaMap

@MainActor
struct AddPlaceViewModelTests {
    private let png = Data([0x89, 0x50, 0x4E, 0x47])

    private func makeSUT(
        search: PlaceSearchRepositoryStub = PlaceSearchRepositoryStub(),
        add: PlaceAddRepositoryStub = PlaceAddRepositoryStub()
    ) -> AddPlaceViewModel {
        AddPlaceViewModel(mapID: 7, searchRepository: search, addRepository: add, sleep: { _ in })
    }

    private func map(type: MapType = .community, role: MapRole = .member) -> MapDetail {
        MapDetail.fixture(id: 7, joined: true, type: type, role: role)
    }

    @Test func 검색어를_멈추면_검색하고_마지막_검색어만_남긴다() async {
        let search = PlaceSearchRepositoryStub()
        search.result = { query in [PlaceCandidate.fixture(id: query)] }
        let sut = makeSUT(search: search)
        sut.updateQuery("카")
        sut.updateQuery("카페")
        await sut.searchTask?.value
        #expect(search.queries == ["카페"])
        #expect(sut.uiState.search == .loaded([.fixture(id: "카페")]))
    }

    @Test func 검색어를_비우면_처음_상태로_돌아간다() async {
        let sut = makeSUT()
        sut.updateQuery("카페")
        await sut.searchTask?.value
        sut.updateQuery("  ")
        #expect(sut.uiState.search == .idle)
    }

    @Test func 검색에_실패하면_다시_시도할_수_있다() async {
        let search = PlaceSearchRepositoryStub()
        search.result = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = makeSUT(search: search)
        sut.updateQuery("카페")
        await sut.searchTask?.value
        #expect(sut.uiState.search == .failed("장소를 검색하지 못했어요"))
        search.result = { _ in [] }
        sut.retrySearch()
        #expect(sut.uiState.search == .loading)
        await sut.searchTask?.value
        #expect(sut.uiState.search == .loaded([]))
    }

    @Test func 검색으로_돌아가면_폼만_비우고_검색_결과는_남긴다() async {
        let sut = makeSUT()
        sut.updateQuery("카페")
        await sut.searchTask?.value
        sut.select(.fixture())
        sut.updateTagInput("성수 ")
        sut.updateMemo("메모")
        sut.addPhoto(data: png, type: .png)
        sut.backToSearch()
        #expect(!sut.uiState.isFormStep)
        #expect(sut.uiState.tags.isEmpty && sut.uiState.memo.isEmpty && sut.uiState.photos.isEmpty)
        #expect(sut.uiState.search == .loaded([]))
    }

    @Test func 사진은_다섯_장까지_같은_사진은_한_번만_붙는다() {
        let sut = makeSUT()
        sut.addPhoto(data: png, type: .png)
        sut.addPhoto(data: png, type: .png)
        #expect(sut.uiState.photos.count == 1)
        for byte in 1...6 { sut.addPhoto(data: png + [UInt8(byte)], type: .png) }
        #expect(sut.uiState.photos.count == 5)
        #expect(!sut.uiState.canAddPhoto)
    }

    @Test func 등록하면_사진을_올리고_역할에_맞는_안내를_남긴다() async {
        let add = PlaceAddRepositoryStub()
        let sut = makeSUT(add: add)
        sut.select(.fixture())
        sut.addPhoto(data: png, type: .png)
        sut.updateTagInput("성수 카페 ")
        sut.updateMemo("좋아요")
        sut.submit(map: map())
        #expect(sut.uiState.submitting)
        await sut.submitTask?.value
        #expect(add.added == [NewPlace(candidate: .fixture(), tags: ["성수", "카페"], memo: "좋아요", photoURLs: ["https://file/0"])])
        #expect(sut.uiState.addedMessage == "추가 요청을 보냈어요")
    }

    @Test func 엔터_없이_등록해도_입력_중인_태그를_넣는다() async {
        let add = PlaceAddRepositoryStub()
        let sut = makeSUT(add: add)
        sut.select(.fixture())
        sut.updateTagInput("성수 카페")
        sut.submit(map: map())
        await sut.submitTask?.value
        #expect(add.added.first?.tags == ["성수", "카페"])
        #expect(sut.uiState.tagInput.isEmpty)
    }

    @Test(arguments: [(MapType.private, MapRole.member), (.community, .owner), (.community, .admin)])
    func 바로_넣을_수_있는_지도는_추가했다고_안내한다(type: MapType, role: MapRole) async {
        let sut = makeSUT()
        sut.select(.fixture())
        #expect(map(type: type, role: role).addPlaceButtonLabel == "추가하기")
        sut.submit(map: map(type: type, role: role))
        await sut.submitTask?.value
        #expect(sut.uiState.addedMessage == "장소를 추가했어요")
    }

    @Test func 등록만_실패하면_다시_보낼_때_올려_둔_사진을_재사용한다() async {
        let add = PlaceAddRepositoryStub()
        add.add = { _ in throw NetworkError.server(code: "PLACE_010", statusCode: 409) }
        let sut = makeSUT(add: add)
        sut.select(.fixture())
        sut.addPhoto(data: png, type: .png)
        sut.submit(map: map())
        await sut.submitTask?.value
        #expect(!sut.uiState.submitting)
        #expect(sut.uiState.errorMessage == "이미 이 지도에 있는 장소예요")
        #expect(sut.uiState.isFormStep)
        add.add = { _ in }
        sut.submit(map: map())
        await sut.submitTask?.value
        #expect(add.uploadCalls == 1)
        #expect(sut.uiState.addedMessage != nil)
    }

    @Test func 사진_업로드에_실패하면_등록하지_않고_이유를_알린다() async {
        let add = PlaceAddRepositoryStub()
        add.upload = { _ in throw ImageUploadError.tooLarge(maxFileSize: 5 * 1024 * 1024) }
        let sut = makeSUT(add: add)
        sut.select(.fixture())
        sut.addPhoto(data: png, type: .png)
        sut.submit(map: map())
        await sut.submitTask?.value
        #expect(add.added.isEmpty)
        #expect(sut.uiState.errorMessage == "사진 크기는 5MB 이하여야 해요")
    }

    @Test func 사진을_바꾸면_올려_둔_주소를_버린다() async {
        let add = PlaceAddRepositoryStub()
        add.add = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = makeSUT(add: add)
        sut.select(.fixture())
        sut.addPhoto(data: png, type: .png)
        sut.submit(map: map())
        await sut.submitTask?.value
        #expect(!sut.uiState.uploadedPhotoURLs.isEmpty)
        sut.removePhoto(at: 0)
        #expect(sut.uiState.uploadedPhotoURLs.isEmpty)
    }

    @Test func 입력이_비었을_때_지우면_마지막_태그를_지운다() {
        let sut = makeSUT()
        sut.updateTagInput("성수 카페 ")
        sut.removeLastTagIfInputEmpty()
        #expect(sut.uiState.tags == ["성수"])
        sut.updateTagInput("데")
        sut.removeLastTagIfInputEmpty()
        #expect(sut.uiState.tags == ["성수"])
    }

    @Test func 입력_중인_태그도_30자를_넘지_않는다() {
        let sut = makeSUT()
        sut.updateTagInput(String(repeating: "가", count: 35))
        #expect(sut.uiState.tagInput == String(repeating: "가", count: 30))
    }

    @Test func 태그는_구분자마다_끊고_중복과_빈_조각을_버리고_30자로_자른다() {
        let long = String(repeating: "가", count: 35)
        let result = TagInput.apply(tags: ["성수"], rawInput: "성수  카페\n\(long) 데이")
        #expect(result.tags == ["성수", "카페", String(repeating: "가", count: 30)])
        #expect(result.input == "데이")
        #expect(TagInput.apply(tags: [], rawInput: "입력중").input == "입력중")
    }
}
