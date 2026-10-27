import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MapPostDetailViewModelTests {
    private let post = MapPost.fixture(id: 3)

    private func viewModel(
        _ repository: MapPostCommentRepositoryStub = MapPostCommentRepositoryStub(), myID: Int64? = 1
    ) -> MapPostDetailViewModel {
        MapPostDetailViewModel(mapID: 10, repository: repository, currentUserStore: MemoryCurrentUserStore(myID))
    }

    @Test func 열기_전에는_닫혀_있고_아무것도_읽지_않는다() {
        let repository = MapPostCommentRepositoryStub()
        let sut = viewModel(repository)
        #expect(sut.uiState.post == nil)
        #expect(repository.fetchCalls.isEmpty)
    }

    @Test func 열면_그_게시물의_댓글과_내_id_를_읽는다() async {
        let repository = MapPostCommentRepositoryStub()
        repository.comments = { _ in [.fixture(id: 1)] }
        let sut = viewModel(repository, myID: 7)
        sut.open(post)
        #expect(sut.uiState.post == post)
        #expect(sut.uiState.comments == .loading)
        await sut.loadTask?.value
        #expect(repository.fetchCalls == [3])
        #expect(sut.uiState.comments == .loaded([.fixture(id: 1)]))
        #expect(sut.uiState.myUserID == 7)
    }

    @Test(arguments: [
        (NetworkError.http(statusCode: 500), "댓글을 불러오지 못했어요"),
        (NetworkError.connection(.notConnectedToInternet), "네트워크에 연결할 수 없어요")
    ])
    func 댓글을_못_읽으면_안내하고_다시_시도하면_다시_읽는다(error: NetworkError, message: String) async {
        let repository = MapPostCommentRepositoryStub()
        repository.comments = { _ in throw error }
        let sut = viewModel(repository)
        sut.open(post)
        await sut.loadTask?.value
        #expect(sut.uiState.comments == .failed(message))

        repository.comments = { _ in [.fixture(id: 1)] }
        sut.retry()
        #expect(sut.uiState.comments == .loading)
        await sut.loadTask?.value
        #expect(sut.uiState.comments == .loaded([.fixture(id: 1)]))
    }

    @Test func 댓글을_남기면_다시_읽지_않고_맨_아래에_붙인다() async {
        let repository = MapPostCommentRepositoryStub()
        repository.comments = { _ in [.fixture(id: 1)] }
        let sut = viewModel(repository)
        sut.open(post)
        await sut.loadTask?.value
        sut.send("  반가워요 ")
        #expect(sut.uiState.sending)
        await sut.sendTask?.value
        #expect(repository.sent == ["반가워요"])
        #expect(repository.fetchCalls.count == 1)
        #expect(sut.uiState.comments == .loaded([.fixture(id: 1), .fixture(id: 99, authorID: 1, content: "반가워요")]))
        #expect(!sut.uiState.sending)
        #expect(sut.uiState.sentCount == 1)
    }

    @Test(arguments: ["", "   \n"])
    func 빈_댓글은_보내지_않는다(content: String) async {
        let repository = MapPostCommentRepositoryStub()
        let sut = viewModel(repository)
        sut.open(post)
        await sut.loadTask?.value
        sut.send(content)
        #expect(sut.sendTask == nil)
        #expect(repository.sent.isEmpty)
    }

    @Test func 오백자를_넘는_댓글은_잘라_보낸다() async {
        let repository = MapPostCommentRepositoryStub()
        let sut = viewModel(repository)
        sut.open(post)
        await sut.loadTask?.value
        sut.send(String(repeating: "가", count: 600))
        await sut.sendTask?.value
        #expect(repository.sent.first?.count == MapPostDetailUiState.maxCommentLength)
    }

    @Test func 댓글을_다_읽기_전에는_보내지_않는다() async {
        let repository = MapPostCommentRepositoryStub()
        let gate = AsyncGate()
        repository.comments = { _ in await gate.wait(); return [] }
        let sut = viewModel(repository)
        sut.open(post)
        sut.send("먼저")
        #expect(repository.sent.isEmpty)
        #expect(!sut.uiState.sending)
        await gate.open()
        await sut.loadTask?.value
    }

    @Test func 댓글을_못_남기면_목록은_두고_알린다() async {
        let repository = MapPostCommentRepositoryStub()
        repository.comments = { _ in [.fixture(id: 1)] }
        repository.create = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = viewModel(repository)
        sut.open(post)
        await sut.loadTask?.value
        sut.send("글")
        await sut.sendTask?.value
        #expect(sut.uiState.comments == .loaded([.fixture(id: 1)]))
        #expect(sut.uiState.sendErrorMessage == MapPostDetailViewModel.sendFailedMessage)
        #expect(!sut.uiState.sending)
        #expect(sut.uiState.sentCount == 0)
    }

    @Test func 닫으면_비우고_다시_열면_새로_읽는다() async {
        let repository = MapPostCommentRepositoryStub()
        repository.comments = { _ in [.fixture(id: 1)] }
        let sut = viewModel(repository)
        sut.open(post)
        await sut.loadTask?.value
        sut.close()
        #expect(sut.uiState == MapPostDetailUiState())
        sut.open(post)
        await sut.loadTask?.value
        #expect(repository.fetchCalls == [3, 3])
    }

    @Test func 다른_게시물을_열면_앞_게시물의_늦은_응답은_버린다() async {
        let repository = MapPostCommentRepositoryStub()
        let gate = AsyncGate()
        repository.comments = { postID in
            if postID == 3 { await gate.wait() }
            return [.fixture(id: postID)]
        }
        let sut = viewModel(repository)
        sut.open(post)
        let stale = sut.loadTask
        sut.open(.fixture(id: 4))
        await sut.loadTask?.value
        await gate.open()
        await stale?.value
        #expect(sut.uiState.post?.id == 4)
        #expect(sut.uiState.comments == .loaded([.fixture(id: 4)]))
    }

    @Test func 내_댓글을_지우면_다시_읽지_않고_목록에서_뺀다() async {
        let repository = MapPostCommentRepositoryStub()
        repository.comments = { _ in [.fixture(id: 1, authorID: 1), .fixture(id: 2, authorID: 2)] }
        let sut = viewModel(repository)
        sut.open(post)
        await sut.loadTask?.value
        sut.delete(commentID: 1)
        await sut.deleteTask?.value
        #expect(repository.deleted == [1])
        #expect(repository.fetchCalls == [3])
        #expect(sut.uiState.comments == .loaded([.fixture(id: 2, authorID: 2)]))
        #expect(sut.uiState.deletedCount == 1)
        #expect(!sut.uiState.deleting)
    }

    @Test func 남의_댓글은_지우지_않는다() async {
        let repository = MapPostCommentRepositoryStub()
        repository.comments = { _ in [.fixture(id: 2, authorID: 2)] }
        let sut = viewModel(repository)
        sut.open(post)
        await sut.loadTask?.value
        sut.delete(commentID: 2)
        #expect(sut.deleteTask == nil)
        #expect(repository.deleted.isEmpty)
    }

    @Test func 지우지_못하면_댓글을_두고_안내한다() async {
        let repository = MapPostCommentRepositoryStub()
        repository.comments = { _ in [.fixture(id: 1, authorID: 1)] }
        repository.delete = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = viewModel(repository)
        sut.open(post)
        await sut.loadTask?.value
        sut.delete(commentID: 1)
        await sut.deleteTask?.value
        #expect(sut.uiState.comments == .loaded([.fixture(id: 1, authorID: 1)]))
        #expect(sut.uiState.deleteErrorMessage == "댓글을 삭제하지 못했어요")
        #expect(sut.uiState.deletedCount == 0)
    }
}
