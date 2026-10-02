import Foundation
import Observation
import UniformTypeIdentifiers

nonisolated struct PlaceReviewUiState: Equatable, Sendable {
    /// 어느 장소의 상태인지. 안 보면 직전 장소의 댓글이 한 프레임 스쳐 간다.
    var placeID: Int64?
    var loading = false
    var reviews: [PlaceReview] = []
    /// 목록을 아예 못 읽었다. 댓글이 없는 것과 구분해 다시 시도할 자리를 준다.
    var loadErrorMessage: String?
    var submitting = false
    var submitErrorMessage: String?
    /// 서버가 받아들인 작성·수정 수. 늘어나면 입력창을 비운다.
    var submittedCount = 0
    var myUserID: Int64?
    /// 입력창에서 고치고 있는 내 댓글.
    var editingReviewID: Int64?
    var deleting = false
    /// 지운 댓글 수. 입력창은 비우지 않고 장소의 댓글 수만 다시 읽는다.
    var deletedCount = 0

    var editingReview: PlaceReview? {
        editingReviewID.flatMap { id in reviews.first { $0.id == id } }
    }
}

@MainActor @Observable
final class PlaceReviewViewModel {
    private(set) var uiState = PlaceReviewUiState()
    private(set) var loadTask: Task<Void, Never>?
    private(set) var submitTask: Task<Void, Never>?
    private(set) var deleteTask: Task<Void, Never>?

    private let repository: any PlaceReviewRepository
    private let now: () -> Date

    init(repository: any PlaceReviewRepository, currentUserStore: any CurrentUserStore, now: @escaping () -> Date) {
        self.repository = repository
        self.now = now
        uiState.myUserID = try? currentUserStore.load()
    }

    /// 이미 그 장소를 보고 있으면 다시 읽지 않는다.
    func open(placeID: Int64) {
        guard uiState.placeID != placeID else { return }
        submitTask?.cancel()
        uiState = PlaceReviewUiState(placeID: placeID, loading: true, myUserID: uiState.myUserID)
        load(placeID)
    }

    /// 다음에 열 때 서버에서 다시 읽도록 비운다.
    func close() {
        loadTask?.cancel()
        submitTask?.cancel()
        uiState = PlaceReviewUiState(myUserID: uiState.myUserID)
    }

    func retry() {
        guard let placeID = uiState.placeID else { return }
        uiState.loading = true
        uiState.loadErrorMessage = nil
        load(placeID)
    }

    /// 보내기 시작했는지를 돌려준다. 입력창은 `submittedCount` 가 늘 때 비운다.
    @discardableResult
    func submit(content: String, photo: UploadImage?) -> Bool {
        guard let placeID = uiState.placeID, !uiState.submitting else { return false }
        if let editing = uiState.editingReview { return update(placeID: placeID, editing: editing, content: content) }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || photo != nil else {
            uiState.submitErrorMessage = PlaceReviewMessage.empty
            return false
        }
        run(placeID: placeID, failure: { PlaceReviewMessage.submitMessage(for: $0) }) { [repository] in
            try await repository.createReview(placeID: placeID, content: text, photo: photo)
        }
        return true
    }

    /// 고른 사진을 서버가 받는 형식으로 바꾼다. 못 읽으면 입력창 아래에 알린다.
    func preparePhoto(data: Data?, type: UTType?) -> UploadImage? {
        do {
            guard let data else { throw ImageUploadError.unreadable }
            let image = try UploadImage(pickedData: data, type: type)
            uiState.submitErrorMessage = nil
            return image
        } catch {
            uiState.submitErrorMessage = (error as? ImageUploadError ?? .unreadable).userMessage
            return nil
        }
    }

    /// 남의 댓글이면 무시한다. 서버가 작성자만 받는다.
    func startEdit(reviewID: Int64) {
        guard !uiState.submitting,
              uiState.reviews.first(where: { $0.id == reviewID })?.isMine(uiState.myUserID) == true else { return }
        uiState.editingReviewID = reviewID
        uiState.submitErrorMessage = nil
    }

    func cancelEdit() {
        guard !uiState.submitting else { return }
        uiState.editingReviewID = nil
        uiState.submitErrorMessage = nil
    }

    /// 확인은 화면이 먼저 받는다.
    func delete(reviewID: Int64) {
        guard let placeID = uiState.placeID, !uiState.deleting,
              uiState.reviews.first(where: { $0.id == reviewID })?.isMine(uiState.myUserID) == true else { return }
        uiState.deleting = true
        uiState.submitErrorMessage = nil
        deleteTask = Task { [weak self, repository] in
            do {
                try await repository.deleteReview(placeID: placeID, reviewID: reviewID)
                guard let self, self.uiState.placeID == placeID else { return }
                self.uiState.deleting = false
                self.uiState.deletedCount += 1
                // 고치던 댓글을 지웠으면 고치기도 끝난다.
                if self.uiState.editingReviewID == reviewID { self.uiState.editingReviewID = nil }
                self.load(placeID)
                await self.loadTask?.value
            } catch {
                guard !(error is CancellationError), let self, self.uiState.placeID == placeID else { return }
                self.uiState.deleting = false
                self.uiState.submitErrorMessage = MapDetailMessage.userMessage(for: error, fallback: PlaceReviewMessage.deleteFailed)
            }
        }
    }

    /// "2시간 전" 처럼 읽는다. 시각을 못 읽었으면 빈 문자열이다.
    func relativeTime(of review: PlaceReview) -> String {
        review.createdAt.map { RelativeTimeLabel.text(from: $0, now: now()) } ?? ""
    }

    /// 사진은 건드리지 않는다. 사진이 있는 댓글은 글을 비워도 된다.
    private func update(placeID: Int64, editing: PlaceReview, content: String) -> Bool {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !editing.imageURLs.isEmpty else {
            uiState.submitErrorMessage = PlaceReviewMessage.empty
            return false
        }
        run(placeID: placeID, failure: { MapDetailMessage.userMessage(for: $0, fallback: PlaceReviewMessage.updateFailed) }) {
            [repository] in
            try await repository.updateReview(placeID: placeID, reviewID: editing.id, content: text)
        }
        return true
    }

    private func run(placeID: Int64, failure: @escaping (any Error) -> String, _ body: @escaping () async throws -> Void) {
        uiState.submitting = true
        uiState.submitErrorMessage = nil
        submitTask?.cancel()
        submitTask = Task { [weak self] in
            do {
                try await body()
                try Task.checkCancellation()
                guard let self else { return }
                self.uiState.submitting = false
                self.uiState.editingReviewID = nil
                self.uiState.submittedCount += 1
                // 방금 쓴 글이 서버가 매긴 순서와 닉네임 그대로 보여야 한다.
                self.load(placeID)
                await self.loadTask?.value
            } catch {
                guard !Task.isCancelled, !(error is CancellationError), let self else { return }
                self.uiState.submitting = false
                self.uiState.submitErrorMessage = failure(error)
            }
        }
    }

    /// 늦게 온 응답이 다른 장소의 상태를 덮지 않게 장소를 다시 본다.
    private func load(_ placeID: Int64) {
        loadTask?.cancel()
        loadTask = Task { [weak self, repository] in
            do {
                let reviews = try await repository.fetchReviews(placeID: placeID)
                try Task.checkCancellation()
                guard let self, self.uiState.placeID == placeID else { return }
                self.uiState.loading = false
                self.uiState.reviews = reviews
                self.uiState.loadErrorMessage = nil
            } catch {
                guard !Task.isCancelled, !(error is CancellationError), let self, self.uiState.placeID == placeID else { return }
                self.uiState.loading = false
                self.uiState.loadErrorMessage = MapDetailMessage.userMessage(for: error, fallback: PlaceReviewMessage.loadFailed)
            }
        }
    }
}

nonisolated enum PlaceReviewMessage {
    static let loadFailed = "댓글을 불러오지 못했어요"
    static let submitFailed = "댓글을 남기지 못했어요"
    static let notMember = "지도에 참여해야 댓글을 남길 수 있어요"
    static let empty = "내용이나 사진을 남겨주세요"
    static let updateFailed = "댓글을 수정하지 못했어요"
    static let deleteFailed = "댓글을 삭제하지 못했어요"

    /// 멤버가 아닌 경우와 사진 문제는 따로 알린다. 뭉뚱그리면 같은 글을 계속 다시 보내게 된다.
    static func submitMessage(for error: any Error) -> String {
        if case .server(code: "PLACE_002", _) = error as? NetworkError { return notMember }
        if let error = error as? ImageUploadError { return error.userMessage }
        return MapDetailMessage.userMessage(for: error, fallback: submitFailed)
    }
}

nonisolated enum RelativeTimeLabel {
    static func text(from date: Date, now: Date) -> String {
        let elapsed = Int(now.timeIntervalSince(date))
        let minute = 60, hour = 60 * minute, day = 24 * hour, week = 7 * day, month = 30 * day, year = 365 * day
        return switch elapsed {
        case ..<minute: "방금 전"
        case ..<hour: "\(elapsed / minute)분 전"
        case ..<day: "\(elapsed / hour)시간 전"
        case ..<week: "\(elapsed / day)일 전"
        case ..<month: "\(elapsed / week)주일 전"
        case ..<year: "\(elapsed / month)개월 전"
        default: "\(elapsed / year)년 전"
        }
    }
}
