import Foundation
import Observation

nonisolated struct PersonalMapAddUiState: Equatable, Sendable {
    /// 어느 장소의 결과인지. 다른 장소를 열었는데 앞 장소의 안내가 남으면 안 된다.
    var placeID: Int64?
    var adding = false
    var message: String?
    var failed = false
}

@MainActor @Observable
final class PersonalMapAddViewModel {
    private(set) var uiState = PersonalMapAddUiState()
    private(set) var addTask: Task<Void, Never>?

    private let repository: any PersonalMapRepository

    init(repository: any PersonalMapRepository) {
        self.repository = repository
    }

    /// 같은 장소면 남아 있는 안내를 그대로 둔다.
    func open(placeID: Int64) {
        guard uiState.placeID != placeID else { return }
        addTask?.cancel()
        uiState = PersonalMapAddUiState(placeID: placeID)
    }

    func close() {
        addTask?.cancel()
        uiState = PersonalMapAddUiState()
    }

    /// 같은 장소가 두 번 들어가면 두 번째는 중복으로 실패해 누르는 동안 다시 받지 않는다.
    func add() {
        guard let placeID = uiState.placeID, !uiState.adding else { return }
        uiState.adding = true
        uiState.message = nil
        uiState.failed = false
        addTask = Task { [weak self, repository] in
            let message: String
            let failed: Bool
            do {
                try await repository.addPlace(placeID: placeID)
                message = PersonalMapMessage.added
                failed = false
            } catch {
                guard !(error is CancellationError) else { return }
                message = PersonalMapMessage.message(for: error)
                failed = true
            }
            guard !Task.isCancelled, let self, self.uiState.placeID == placeID else { return }
            self.uiState.adding = false
            self.uiState.message = message
            self.uiState.failed = failed
        }
    }
}

nonisolated enum PersonalMapMessage {
    static let added = "나만의 지도에 추가했어요"
    static let duplicate = "이미 나만의 지도에 있는 장소예요"
    static let notFound = "나만의 지도를 찾지 못했어요"
    static let failed = "나만의 지도에 추가하지 못했어요"

    static func message(for error: any Error) -> String {
        if case .server(code: "PLACE_010", _, _) = error as? NetworkError { return duplicate }
        if error is PersonalMapNotFoundError { return notFound }
        return MapDetailMessage.userMessage(for: error, fallback: failed)
    }
}
