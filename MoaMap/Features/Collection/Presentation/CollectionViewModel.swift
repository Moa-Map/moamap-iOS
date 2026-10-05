import Foundation
import Observation

@MainActor @Observable
final class CollectionViewModel {
    private(set) var uiState = CollectionUiState()
    // 취소는 오류 상태로 바꾸지 않고 호출자에게 전파한다.
    private(set) var loadTasks: [CollectionMapType: Task<Void, any Error>] = [:]
    var loadTask: Task<Void, any Error>? { loadTasks[uiState.selectedTab] }
    private(set) var joinTask: Task<Void, any Error>?

    private var requestedTabs: Set<CollectionMapType> = []
    private let repository: any CollectionRepository

    init(repository: any CollectionRepository) {
        self.repository = repository
    }

    func loadIfNeeded() {
        guard !requestedTabs.contains(uiState.selectedTab) else { return }
        load(uiState.selectedTab)
    }

    func selectTab(_ type: CollectionMapType) {
        guard type != uiState.selectedTab else { return }
        uiState.selectedTab = type
        loadIfNeeded()
    }

    func retry() {
        load(uiState.selectedTab)
    }

    /// 화면 재진입 시 현재 목록은 유지하며 갱신하고, 다른 탭은 다음 선택 때 갱신한다.
    func refresh() {
        requestedTabs = requestedTabs.intersection([uiState.selectedTab])
        load(uiState.selectedTab, keepCurrent: true)
    }

    func openJoinDialog() {
        uiState.join = .editing(JoinMapEditing())
    }

    func closeJoinDialog() {
        // 요청 중에 닫으면 결과를 알릴 곳이 사라진다.
        if case .editing(let editing) = uiState.join, editing.submitting { return }
        uiState.join = .hidden
    }

    /// `#` 은 장식이라 값에 넣지 않는다. 서버 코드는 ASCII 영숫자다.
    func updateInviteCode(_ input: String) {
        guard case .editing(var editing) = uiState.join, !editing.submitting else { return }
        editing.code = input.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.uppercased()
        editing.errorMessage = nil
        uiState.join = .editing(editing)
    }

    /// 성공하면 합류한 지도가 보이도록 프라이빗 탭으로 옮겨 다시 읽는다.
    func join() {
        guard case .editing(var editing) = uiState.join, editing.canSubmit else { return }
        editing.submitting = true
        editing.errorMessage = nil
        uiState.join = .editing(editing)

        joinTask = Task { [weak self, repository, code = editing.code] in
            do {
                try await repository.joinByInviteCode(code)
                try Task.checkCancellation()
                guard let self else { return }
                uiState.join = .hidden
                uiState.selectedTab = .private
                load(.private)
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                editing.submitting = false
                editing.errorMessage = Self.joinMessage(for: error)
                self?.uiState.join = .editing(editing)
            }
        }
    }

    private static func joinMessage(for error: any Error) -> String {
        switch error as? NetworkError {
        case .connection: "네트워크에 연결할 수 없어요"
        case .server(code: "MAP_007", _): "코드를 다시 확인해주세요"
        case .server(code: "MAP_005", _): "이미 참여 중인 지도예요"
        default: "지도에 참여하지 못했어요"
        }
    }

    private func load(_ type: CollectionMapType, keepCurrent: Bool = false) {
        loadTasks[type]?.cancel()
        requestedTabs.insert(type)
        if !keepCurrent || uiState.state(of: type) == .idle {
            uiState.setState(.loading, for: type)
        }
        loadTasks[type] = Task { [weak self, repository] in
            defer {
                if !Task.isCancelled { self?.loadTasks[type] = nil }
            }
            do {
                let maps = try await repository.fetchMyMaps(type: type)
                try Task.checkCancellation()
                self?.uiState.setState(.loaded(maps), for: type)
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                guard let self else { return }
                if keepCurrent, case .loaded = uiState.state(of: type) { return }
                uiState.setState(.failed("지도 목록을 불러오지 못했어요"), for: type)
            }
        }
    }
}
