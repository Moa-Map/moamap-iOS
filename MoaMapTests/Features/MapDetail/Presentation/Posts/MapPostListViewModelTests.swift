import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MapPostListViewModelTests {
    private func posts(_ ids: Int64...) -> [MapPost] { ids.map(MapPost.fixture(id:)) }

    @Test func 만들어지기만_하면_조회하지_않는다() {
        let repository = MapPostRepositoryStub()
        let sut = MapPostListViewModel(mapID: 7, repository: repository)
        #expect(repository.requests.isEmpty)
        #expect(sut.uiState.list == .loading)
    }

    @Test func 로그_탭을_열면_최신순_첫_페이지를_읽는다() async {
        let repository = MapPostRepositoryStub()
        let sut = MapPostListViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        #expect(repository.requests == [.init(page: 0, sort: .latest)])
        #expect(sut.uiState == MapPostListUiState(sort: .latest, list: .loaded(posts(1, 2)), paging: .end))
    }

    @Test func 탭을_오갈_때마다_다시_읽지_않는다() async {
        let repository = MapPostRepositoryStub()
        let sut = MapPostListViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        sut.loadOnce()
        await sut.loadTask?.value
        #expect(repository.requests.count == 1)
    }

    @Test func 끝에_닿으면_다음_페이지를_이어_붙인다() async {
        let repository = MapPostRepositoryStub()
        repository.pages = [.latest: [
            MapPostPage(posts: posts(1, 2), isLast: false),
            MapPostPage(posts: posts(3), isLast: true)
        ]]
        let sut = MapPostListViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        #expect(sut.uiState.paging == .idle)
        sut.loadMore()
        #expect(sut.uiState.paging == .loading)
        await sut.loadTask?.value
        #expect(repository.requests.map(\.page) == [0, 1])
        #expect(sut.uiState.posts == posts(1, 2, 3))
        #expect(sut.uiState.paging == .end)
    }

    @Test func 마지막_페이지를_받은_뒤에는_더_부르지_않는다() async {
        let repository = MapPostRepositoryStub()
        let sut = MapPostListViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        sut.loadMore()
        #expect(repository.requests.count == 1)
    }

    @Test func 첫_페이지를_받는_중에는_다음_페이지를_부르지_않는다() async {
        let repository = MapPostRepositoryStub()
        let gate = AsyncGate()
        repository.gate = gate
        let sut = MapPostListViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        sut.loadMore()
        await gate.open()
        await sut.loadTask?.value
        #expect(repository.requests == [.init(page: 0, sort: .latest)])
    }

    @Test func 다음_페이지에_이미_받은_글이_섞이면_한_번만_둔다() async {
        let repository = MapPostRepositoryStub()
        repository.pages = [.latest: [
            MapPostPage(posts: posts(1, 2), isLast: false),
            MapPostPage(posts: posts(2, 3), isLast: true)
        ]]
        let sut = MapPostListViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        sut.loadMore()
        await sut.loadTask?.value
        #expect(sut.uiState.posts.map(\.id) == [1, 2, 3])
    }

    @Test func 정렬을_바꾸면_첫_페이지부터_다시_읽는다() async {
        let repository = MapPostRepositoryStub()
        repository.pages = [
            .latest: [MapPostPage(posts: posts(2, 1), isLast: true)],
            .oldest: [MapPostPage(posts: posts(1, 2), isLast: true)]
        ]
        let sut = MapPostListViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        sut.selectSort(.oldest)
        #expect(sut.uiState.list == .loading)
        await sut.loadTask?.value
        #expect(repository.requests.last == .init(page: 0, sort: .oldest))
        #expect(sut.uiState == MapPostListUiState(sort: .oldest, list: .loaded(posts(1, 2)), paging: .end))
    }

    @Test func 같은_정렬을_다시_누르면_다시_읽지_않는다() async {
        let repository = MapPostRepositoryStub()
        let sut = MapPostListViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        sut.selectSort(.latest)
        await sut.loadTask?.value
        #expect(repository.requests.count == 1)
    }

    @Test func 다음_페이지를_받는_중에_정렬을_바꾸면_그_응답은_버린다() async {
        let repository = MapPostRepositoryStub()
        repository.pages = [
            .latest: [MapPostPage(posts: posts(1), isLast: false), MapPostPage(posts: posts(9), isLast: true)],
            .oldest: [MapPostPage(posts: posts(5), isLast: true)]
        ]
        let sut = MapPostListViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        let gate = AsyncGate()
        repository.gate = gate
        sut.loadMore()
        let stale = sut.loadTask
        sut.selectSort(.oldest)
        await gate.open()
        await stale?.value
        await sut.loadTask?.value
        #expect(sut.uiState == MapPostListUiState(sort: .oldest, list: .loaded(posts(5)), paging: .end))
    }

    @Test func 첫_페이지를_못_읽으면_안내를_남기고_재시도하면_다시_읽는다() async {
        let repository = MapPostRepositoryStub()
        repository.failingPage = 0
        let sut = MapPostListViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        #expect(sut.uiState.list == .failed(MapPostListViewModel.loadFailedMessage))
        sut.loadMore()
        #expect(repository.requests.count == 1)

        repository.failingPage = nil
        sut.retry()
        #expect(sut.uiState.list == .loading)
        await sut.loadTask?.value
        #expect(sut.uiState.posts == posts(1, 2))
    }

    @Test func 연결이_끊겨_못_읽으면_연결_안내를_띄운다() async {
        let sut = MapPostListViewModel(mapID: 7, repository: ConnectionFailingMapPostRepository())
        sut.loadOnce()
        await sut.loadTask?.value
        #expect(sut.uiState.list == .failed("네트워크에 연결할 수 없어요"))
    }

    @Test func 다음_페이지를_못_읽으면_받은_목록은_두고_실패만_표시한다() async {
        let repository = MapPostRepositoryStub()
        repository.pages = [.latest: [
            MapPostPage(posts: posts(1), isLast: false),
            MapPostPage(posts: posts(2), isLast: true)
        ]]
        repository.failingPage = 1
        let sut = MapPostListViewModel(mapID: 7, repository: repository)
        sut.loadOnce()
        await sut.loadTask?.value
        sut.loadMore()
        await sut.loadTask?.value
        #expect(sut.uiState.posts == posts(1))
        #expect(sut.uiState.paging == .failed)

        repository.failingPage = nil
        sut.loadMore()
        await sut.loadTask?.value
        #expect(repository.requests.map(\.page) == [0, 1, 1])
        #expect(sut.uiState.posts == posts(1, 2))
    }
}

@MainActor
private final class ConnectionFailingMapPostRepository: MapPostRepository {
    func fetchPosts(mapID: Int64, page: Int, sort: MapPostSort) async throws -> MapPostPage {
        throw NetworkError.connection(.notConnectedToInternet)
    }
    func uploadPhotos(mapID: Int64, photos: [UploadImage]) async throws -> [String] { [] }
    func createPost(mapID: Int64, post: NewMapPost) async throws {}
}
