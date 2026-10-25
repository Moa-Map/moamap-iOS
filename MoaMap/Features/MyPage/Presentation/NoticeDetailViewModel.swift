import Foundation
import Observation

nonisolated enum NoticeDetailUiState: Equatable, Sendable {
    case loading
    case loaded(Notice)
    case failed(String)
}

/// 목록이 들고 있는 값을 넘기지 않고 다시 읽는다. 목록을 본 뒤 고쳐졌거나 지워졌을 수 있다.
@MainActor @Observable
final class NoticeDetailViewModel {
    /// 다시 불러와도 같다.
    nonisolated static let deletedMessage = "삭제된 공지사항이에요"

    private(set) var uiState: NoticeDetailUiState = .loading
    private(set) var loadTask: Task<Void, Never>?
    private let noticeID: Int64
    private let repository: any NoticeRepository
    private let timeZone: TimeZone

    init(noticeID: Int64, repository: any NoticeRepository, timeZone: TimeZone) {
        self.noticeID = noticeID
        self.repository = repository
        self.timeZone = timeZone
    }

    func load() {
        loadTask?.cancel()
        uiState = .loading
        loadTask = Task { [weak self, noticeID, repository] in
            do {
                let notice = try await repository.fetchNotice(id: noticeID)
                try Task.checkCancellation()
                self?.uiState = .loaded(notice)
            } catch is CancellationError {
                // Task<Void, Never> 경계. 취소된 요청은 화면을 바꾸지 않는다.
            } catch {
                guard !Task.isCancelled else { return }
                self?.uiState = .failed(Self.message(for: error))
            }
        }
    }

    func dateLabel(of date: Date?) -> String? {
        NoticeDateLabel.text(date, timeZone: timeZone)
    }

    private nonisolated static func message(for error: any Error) -> String {
        switch error as? NetworkError {
        case .server(_, 404, _), .http(404): deletedMessage
        default: NoticeListViewModel.message(for: error)
        }
    }
}
