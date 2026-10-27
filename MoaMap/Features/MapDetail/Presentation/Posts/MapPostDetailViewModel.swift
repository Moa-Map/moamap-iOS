import Foundation
import Observation

nonisolated enum MapPostCommentsState: Equatable, Sendable {
    case loading
    case loaded([MapPostComment])
    case failed(String)
}

/// 게시물 상세. `post` 가 nil 이면 상세가 닫혀 있다.
/// 댓글을 못 읽은 것(`comments`)과 못 남긴 것(`sendErrorMessage`)을 나눈다. 뒤는 보이는 댓글을 둔 채 입력칸 아래에만 알린다.
nonisolated struct MapPostDetailUiState: Equatable, Sendable {
    /// 댓글 한 건의 서버 한도.
    static let maxCommentLength = 500

    var post: MapPost?
    var comments: MapPostCommentsState = .loading
    /// 내 댓글을 오른쪽에 둔다. 모르면 모두 남의 댓글처럼 그린다.
    var myUserID: Int64?
    var sending = false
    var sendErrorMessage: String?
    /// 남긴 댓글 수. 늘면 화면이 입력칸을 비우고 맨 아래로 내린다.
    var sentCount = 0
    var deleting = false
    /// 지운 댓글 수. 늘면 화면이 토스트를 띄운다.
    var deletedCount = 0
    var deleteErrorMessage: String?

    /// 댓글을 다 읽기 전에는 보내지 않는다. 먼저 보낸 댓글을 늦게 온 목록이 덮는다.
    var commentsReady: Bool {
        if case .loaded = comments { true } else { false }
    }
}

/// 로그 탭 게시물 상세와 댓글. 게시물 내용은 목록에서 받은 것을 그대로 쓴다.
@MainActor @Observable
final class MapPostDetailViewModel {
    nonisolated static let loadFailedMessage = "댓글을 불러오지 못했어요"
    nonisolated static let sendFailedMessage = "댓글을 남기지 못했어요"
    nonisolated static let deleteFailedMessage = "댓글을 삭제하지 못했어요"

    let mapID: Int64
    private(set) var uiState = MapPostDetailUiState()
    private(set) var loadTask: Task<Void, Never>?
    private(set) var sendTask: Task<Void, Never>?
    private(set) var deleteTask: Task<Void, Never>?

    private let repository: any MapPostCommentRepository
    private let currentUserStore: any CurrentUserStore

    init(mapID: Int64, repository: any MapPostCommentRepository, currentUserStore: any CurrentUserStore) {
        self.mapID = mapID
        self.repository = repository
        self.currentUserStore = currentUserStore
    }

    /// 다른 게시물을 보던 중이면 그 요청은 버린다.
    func open(_ post: MapPost) {
        cancelTasks()
        uiState = MapPostDetailUiState(post: post)
        load(post)
    }

    func close() {
        cancelTasks()
        uiState = MapPostDetailUiState()
    }

    func retry() {
        guard let post = uiState.post else { return }
        uiState.comments = .loading
        load(post)
    }

    /// 앞뒤 공백을 지우고 비었으면 보내지 않는다.
    /// 성공하면 다시 읽지 않고 받은 댓글을 맨 아래에 붙인다. 다시 읽다 실패하면 남긴 댓글이 없던 일처럼 보인다.
    func send(_ content: String) {
        let state = uiState
        guard let post = state.post, case .loaded = state.comments, !state.sending else { return }
        let text = String(content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(MapPostDetailUiState.maxCommentLength))
        guard !text.isEmpty else { return }
        uiState.sending = true
        uiState.sendErrorMessage = nil
        sendTask = Task { [weak self, repository, mapID] in
            do {
                let comment = try await repository.createComment(mapID: mapID, postID: post.id, content: text)
                try Task.checkCancellation()
                guard let self, case .loaded(let comments) = self.uiState.comments else { return }
                self.uiState.comments = .loaded(comments + [comment])
                self.uiState.sending = false
                self.uiState.sentCount += 1
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.sending = false
                self?.uiState.sendErrorMessage = MapDetailMessage.userMessage(for: error, fallback: Self.sendFailedMessage)
            }
        }
    }

    /// 내 댓글만 지운다. 확인은 화면이 먼저 받는다. 지우면 다시 읽지 않고 목록에서 뺀다.
    func delete(commentID: Int64) {
        let state = uiState
        guard let post = state.post, case .loaded(let comments) = state.comments, !state.deleting,
              let myUserID = state.myUserID, comments.first(where: { $0.id == commentID })?.authorID == myUserID else { return }
        uiState.deleting = true
        uiState.deleteErrorMessage = nil
        deleteTask = Task { [weak self, repository, mapID] in
            do {
                try await repository.deleteComment(mapID: mapID, postID: post.id, commentID: commentID)
                try Task.checkCancellation()
                guard let self, case .loaded(let current) = self.uiState.comments else { return }
                self.uiState.comments = .loaded(current.filter { $0.id != commentID })
                self.uiState.deleting = false
                self.uiState.deletedCount += 1
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.deleting = false
                self?.uiState.deleteErrorMessage = MapDetailMessage.userMessage(for: error, fallback: Self.deleteFailedMessage)
            }
        }
    }

    private func load(_ post: MapPost) {
        loadTask?.cancel()
        loadTask = Task { [weak self, repository, mapID, currentUserStore] in
            do {
                let comments = try await repository.fetchComments(mapID: mapID, postID: post.id)
                try Task.checkCancellation()
                self?.uiState.myUserID = try? currentUserStore.load()
                self?.uiState.comments = .loaded(comments)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.comments = .failed(MapDetailMessage.userMessage(for: error, fallback: Self.loadFailedMessage))
            }
        }
    }

    private func cancelTasks() {
        loadTask?.cancel()
        sendTask?.cancel()
        deleteTask?.cancel()
    }
}
