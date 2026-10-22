import Foundation
import Observation

nonisolated enum TermDetailUiState: Equatable, Sendable {
    case loading
    case loaded(TermDetail)
    case failed(String)
}

@MainActor @Observable
final class TermDetailViewModel {
    static let failureMessage = "약관을 불러오지 못했어요"

    private(set) var uiState: TermDetailUiState = .loading
    private(set) var loadTask: Task<Void, Never>?
    private let termID: Int64
    private let repository: any TermsRepository

    init(termID: Int64, repository: any TermsRepository) {
        self.termID = termID
        self.repository = repository
    }

    func load() {
        loadTask?.cancel()
        uiState = .loading
        loadTask = Task { [weak self, termID, repository] in
            do {
                let detail = try await repository.fetchTerm(id: termID)
                try Task.checkCancellation()
                self?.uiState = .loaded(detail)
            } catch is CancellationError {
                // Task<Void, Never> 경계. 취소된 요청은 화면을 바꾸지 않는다.
            } catch {
                guard !Task.isCancelled else { return }
                self?.uiState = .failed(Self.failureMessage)
            }
        }
    }
}
