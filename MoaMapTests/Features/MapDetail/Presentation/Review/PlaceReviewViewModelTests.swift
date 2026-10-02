import Foundation
import Testing
@testable import MoaMap

@MainActor
struct PlaceReviewViewModelTests {
    private let me: Int64 = 1

    private func makeSUT(_ repository: PlaceReviewRepositoryStub, now: Date = Date(timeIntervalSince1970: 10_000)) -> PlaceReviewViewModel {
        let users = MemoryCurrentUserStore()
        try? users.save(userId: me)
        return PlaceReviewViewModel(repository: repository, currentUserStore: users, now: { now })
    }

    private func opened(_ repository: PlaceReviewRepositoryStub) async -> PlaceReviewViewModel {
        let sut = makeSUT(repository)
        sut.open(placeID: 3)
        await sut.loadTask?.value
        return sut
    }

    @Test func 장소를_열면_댓글을_읽고_같은_장소는_다시_읽지_않는다() async {
        let repository = PlaceReviewRepositoryStub()
        repository.reviews = { _ in [.fixture(id: 1)] }
        let sut = makeSUT(repository)
        sut.open(placeID: 3)
        #expect(sut.uiState.loading)
        await sut.loadTask?.value
        #expect(sut.uiState.reviews == [.fixture(id: 1)])
        sut.open(placeID: 3)
        #expect(repository.fetchCalls == 1)
    }

    @Test func 조회에_실패하면_다시_시도할_수_있다() async {
        let repository = PlaceReviewRepositoryStub()
        repository.reviews = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = await opened(repository)
        #expect(sut.uiState.loadErrorMessage == "댓글을 불러오지 못했어요")
        repository.reviews = { _ in [.fixture(id: 1)] }
        sut.retry()
        await sut.loadTask?.value
        #expect(sut.uiState.loadErrorMessage == nil)
        #expect(sut.uiState.reviews.count == 1)
    }

    @Test func 늦게_온_앞_장소의_댓글은_다른_장소를_덮지_않는다() async {
        let repository = PlaceReviewRepositoryStub()
        let release = AsyncGate()
        repository.reviews = { placeID in
            if placeID == 3 { await release.wait() }
            return [.fixture(id: placeID)]
        }
        let sut = makeSUT(repository)
        sut.open(placeID: 3)
        let old = sut.loadTask
        sut.open(placeID: 4)
        await sut.loadTask?.value
        await release.open()
        await old?.value
        #expect(sut.uiState.reviews == [.fixture(id: 4)])
    }

    @Test func 작성하면_목록을_다시_읽고_입력을_비우라는_신호를_올린다() async {
        let repository = PlaceReviewRepositoryStub()
        let sut = await opened(repository)
        repository.reviews = { _ in [.fixture(id: 9)] }
        #expect(sut.submit(content: "  새 글 ", photo: nil))
        #expect(sut.uiState.submitting)
        await sut.submitTask?.value
        #expect(!sut.uiState.submitting)
        #expect(sut.uiState.submittedCount == 1)
        #expect(sut.uiState.reviews == [.fixture(id: 9)])
    }

    @Test func 글과_사진이_모두_없으면_보내지_않는다() async {
        let repository = PlaceReviewRepositoryStub()
        let sut = await opened(repository)
        #expect(!sut.submit(content: "  ", photo: nil))
        #expect(sut.uiState.submitErrorMessage == "내용이나 사진을 남겨주세요")
        #expect(repository.createCalls == 0)
    }

    @Test(arguments: [
        (NetworkError.server(code: "PLACE_002", statusCode: 403) as any Error, "지도에 참여해야 댓글을 남길 수 있어요"),
        (ImageUploadError.unsupportedType as any Error, "JPG, PNG, WEBP 형식만 올릴 수 있어요"),
        (NetworkError.server(code: "COMMON_005", statusCode: 500) as any Error, "댓글을 남기지 못했어요")
    ])
    func 작성에_실패하면_원인에_맞게_안내한다(error: any Error, message: String) async {
        let repository = PlaceReviewRepositoryStub()
        repository.create = { _, _, _ in throw error }
        let sut = await opened(repository)
        sut.submit(content: "글", photo: nil)
        await sut.submitTask?.value
        #expect(!sut.uiState.submitting)
        #expect(sut.uiState.submittedCount == 0)
        #expect(sut.uiState.submitErrorMessage == message)
    }

    @Test func 내_댓글만_고칠_수_있고_고치면_수정으로_보낸다() async {
        let repository = PlaceReviewRepositoryStub()
        repository.reviews = { _ in [.fixture(id: 1, authorID: 1), .fixture(id: 2, authorID: 2)] }
        let sut = await opened(repository)
        sut.startEdit(reviewID: 2)
        #expect(sut.uiState.editingReviewID == nil)
        sut.startEdit(reviewID: 1)
        #expect(sut.uiState.editingReview?.id == 1)
        sut.submit(content: "고친 글", photo: nil)
        await sut.submitTask?.value
        #expect(repository.lastUpdate?.reviewID == 1)
        #expect(repository.lastUpdate?.content == "고친 글")
        #expect(repository.createCalls == 0)
        #expect(sut.uiState.editingReviewID == nil)
    }

    @Test func 사진이_있는_댓글은_글을_비워도_고칠_수_있다() async throws {
        let repository = PlaceReviewRepositoryStub()
        let photo = try #require(URL(string: "https://p"))
        repository.reviews = { _ in [.fixture(id: 1, imageURLs: [photo]), .fixture(id: 2)] }
        let sut = await opened(repository)
        sut.startEdit(reviewID: 1)
        #expect(sut.submit(content: "", photo: nil))
        await sut.submitTask?.value
        sut.startEdit(reviewID: 2)
        #expect(!sut.submit(content: " ", photo: nil))
    }

    @Test func 지우면_다시_읽고_고치던_댓글이면_고치기도_끝낸다() async {
        let repository = PlaceReviewRepositoryStub()
        repository.reviews = { _ in [.fixture(id: 1)] }
        let sut = await opened(repository)
        sut.startEdit(reviewID: 1)
        repository.reviews = { _ in [] }
        sut.delete(reviewID: 1)
        await sut.deleteTask?.value
        #expect(sut.uiState.deletedCount == 1)
        #expect(sut.uiState.editingReviewID == nil)
        #expect(sut.uiState.reviews.isEmpty)
        #expect(sut.uiState.submittedCount == 0)
    }

    @Test func 남의_댓글은_지우지_않는다() async {
        let repository = PlaceReviewRepositoryStub()
        repository.reviews = { _ in [.fixture(id: 1, authorID: 2)] }
        let sut = await opened(repository)
        sut.delete(reviewID: 1)
        #expect(repository.deleteCalls == 0)
    }

    @Test func 상대_시각은_주입한_현재_시각으로_계산한다() {
        let sut = makeSUT(PlaceReviewRepositoryStub(), now: Date(timeIntervalSince1970: 7200))
        var review = PlaceReview.fixture(id: 1)
        review.createdAt = Date(timeIntervalSince1970: 0)
        #expect(sut.relativeTime(of: review) == "2시간 전")
        review.createdAt = nil
        #expect(sut.relativeTime(of: review) == "")
    }

    @Test(arguments: [(30, "방금 전"), (120, "2분 전"), (86_400 * 3, "3일 전"), (86_400 * 14, "2주일 전"), (86_400 * 60, "2개월 전"), (86_400 * 800, "2년 전")])
    func 상대_시각_구간(elapsed: Int, label: String) {
        #expect(RelativeTimeLabel.text(from: Date(timeIntervalSince1970: 0), now: Date(timeIntervalSince1970: TimeInterval(elapsed))) == label)
    }
}
