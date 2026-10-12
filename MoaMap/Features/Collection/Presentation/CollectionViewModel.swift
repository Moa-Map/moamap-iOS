import Foundation
import Observation

@MainActor @Observable
final class CollectionViewModel {
    static let orderFailedMessage = "지도 순서를 저장하지 못했어요"

    private(set) var uiState = CollectionUiState()
    // 취소는 오류 상태로 바꾸지 않고 호출자에게 전파한다.
    private(set) var loadTasks: [CollectionMapType: Task<Void, any Error>] = [:]
    var loadTask: Task<Void, any Error>? { loadTasks[uiState.selectedTab] }
    private(set) var joinTask: Task<Void, any Error>?
    private(set) var editTask: Task<Void, Never>?
    private(set) var orderTask: Task<Void, Never>?
    /// 끌어서 바꿨지만 아직 서버에 보내지 않은 순서가 있다. 편집을 끝낼 때 보낸다.
    private var orderDirty = false
    /// 보내는 중에 또 바뀐 순서. 앞 요청이 끝나면 마지막 것만 보낸다.
    private var pendingOrder: (type: CollectionMapType, mapIDs: [Int64])?

    private var requestedTabs: Set<CollectionMapType> = []
    private let repository: any CollectionRepository
    /// 모음 목록에는 내 역할이 없어 고른 지도의 상세를 읽어 확인한다. 나가기도 여기로 보낸다.
    private let mapRepository: any MapDetailRepository

    init(repository: any CollectionRepository, mapRepository: any MapDetailRepository) {
        self.repository = repository
        self.mapRepository = mapRepository
    }

    func loadIfNeeded() {
        guard !requestedTabs.contains(uiState.selectedTab) else { return }
        load(uiState.selectedTab)
    }

    func selectTab(_ type: CollectionMapType) {
        guard type != uiState.selectedTab, uiState.editing?.processing != true else { return }
        commitOrder()
        uiState.selectedTab = type
        // 고른 지도는 보던 탭의 것이다. 다른 탭에서 보이지 않는 지도를 나가면 안 된다.
        uiState.editing = nil
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

    func startEditing() {
        uiState.editing = CollectionEditing()
    }

    /// 나가는 중에 끝내면 결과를 알릴 곳이 사라진다.
    func finishEditing() {
        guard uiState.editing?.processing != true else { return }
        commitOrder()
        uiState.editing = nil
        uiState.editDialog = nil
    }

    func toggleSelection(mapID: Int64) {
        guard var editing = uiState.editing, !editing.processing else { return }
        if editing.selectedIDs.remove(mapID) == nil { editing.selectedIDs.insert(mapID) }
        uiState.editing = editing
    }

    /// 끌고 지나가는 자리마다 화면 순서만 바꾼다. 서버에는 편집을 끝낼 때 한 번 보낸다.
    /// 프라이빗 탭은 나만의 지도와 나머지를 따로 보여 주므로 같은 묶음 안에서만 옮긴다.
    /// 옮겼는지 돌려준다. 핸들로 끌 때는 옮긴 만큼만 손가락 위치를 보정해야 한다.
    @discardableResult
    func moveMap(_ mapID: Int64, to targetID: Int64) -> Bool {
        guard uiState.editing?.processing == false, case .loaded(var maps) = uiState.currentMaps,
              let from = maps.firstIndex(where: { $0.id == mapID }),
              let to = maps.firstIndex(where: { $0.id == targetID }),
              from != to, maps[from].personal == maps[to].personal else { return false }
        maps.insert(maps.remove(at: from), at: to)
        uiState.setState(.loaded(maps), for: uiState.selectedTab)
        orderDirty = true
        return true
    }

    /// 서버는 탭의 지도 전체를 받아 순서를 통째로 바꾼다. 실패하면 서버 순서로 되돌린다.
    private func commitOrder() {
        guard orderDirty, case .loaded(let maps) = uiState.currentMaps else { return }
        orderDirty = false
        pendingOrder = (uiState.selectedTab, maps.map(\.id))
        guard orderTask == nil else { return }
        orderTask = Task { [weak self] in
            while let self, let order = pendingOrder {
                pendingOrder = nil
                do {
                    try await repository.updateMapOrder(type: order.type, mapIDs: order.mapIDs)
                } catch {
                    guard !(error is CancellationError) else { break }
                    pendingOrder = nil
                    uiState.notice = MapDetailMessage.userMessage(for: error, fallback: Self.orderFailedMessage)
                    load(order.type, keepCurrent: true)
                    break
                }
            }
            self?.orderTask = nil
        }
    }

    /// 방장인 지도가 섞여 있으면 막고, 아니면 한 번 더 묻는다.
    func requestLeave() {
        guard let editing = uiState.editing, editing.canLeave else { return }
        let ids = editing.selectedIDs.sorted()
        runEditTask { [mapRepository] in
            var maps: [MapDetail] = []
            for id in ids { maps.append(try await mapRepository.fetchMapDetail(mapID: id)) }
            return maps
        } onSuccess: { [weak self] maps in
            // 지도 상세의 나가기 규칙을 그대로 따른다. 혼자 남은 프라이빗 방장의 지도 삭제는 여러 개를 한 번에 하지 않는다.
            if maps.contains(where: { $0.leaveOutcome == nil || $0.leavingDeletesMap }) {
                self?.uiState.editDialog = .ownerCannotLeave
            } else {
                // 프라이빗 지도는 초대 코드로만 다시 들어올 수 있다고 함께 알린다.
                let outcome: LeaveOutcome = maps.contains { $0.type == .private } ? .leaveNeedsInviteCode : .leave
                self?.uiState.editDialog = .confirmLeave(count: maps.count, outcome: outcome)
            }
        }
    }

    /// 나간 지도는 고른 목록에서 빼고, 실패한 지도만 남겨 다시 시도할 수 있게 한다.
    func confirmLeave() {
        guard case .confirmLeave = uiState.editDialog, let editing = uiState.editing, editing.canLeave else { return }
        uiState.editDialog = nil
        let ids = editing.selectedIDs.sorted()
        // 바꾼 순서는 나가기 전에 저장한다. 나간 뒤에는 보낼 목록이 서버와 달라져 `MAP_022` 로 거부된다.
        commitOrder()
        let orderSave = orderTask
        runEditTask { [mapRepository] in
            await orderSave?.value
            var failed: Set<Int64> = []
            var lastError: (any Error)?
            for id in ids {
                do {
                    try await mapRepository.leaveMap(mapID: id)
                } catch {
                    if error is CancellationError { throw error }
                    failed.insert(id)
                    lastError = error
                }
            }
            return (failed, lastError)
        } onSuccess: { [weak self] result in
            guard let self else { return }
            let (failed, lastError) = result
            if let lastError {
                uiState.editing?.selectedIDs = failed
                uiState.notice = MapDetailMessage.userMessage(for: lastError, fallback: MapDetailMessage.leaveFailed)
            } else {
                uiState.editing = nil
            }
            // 일부만 나갔어도 목록은 바뀌었다.
            load(uiState.selectedTab, keepCurrent: true)
        }
    }

    func dismissEditDialog() {
        uiState.editDialog = nil
    }

    /// 수정 권한은 상세를 읽어야 안다. 권한이 있을 때만 수정 화면을 연다.
    func requestEditInfo() {
        guard let editing = uiState.editing, editing.canEditInfo, let id = editing.selectedIDs.first else { return }
        runEditTask { [mapRepository] in
            try await mapRepository.fetchMapDetail(mapID: id)
        } onSuccess: { [weak self] map in
            if map.canEditInfo {
                self?.uiState.mapToEdit = map
            } else {
                self?.uiState.notice = EditMapViewModel.noPermissionMessage
            }
        }
    }

    func consumeMapToEdit() {
        uiState.mapToEdit = nil
    }

    /// 고친 지도가 목록에 바로 보이도록 다시 읽는다.
    func mapEdited() {
        finishEditing()
        load(uiState.selectedTab, keepCurrent: true)
    }

    func consumeNotice() {
        uiState.notice = nil
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
        case .server(code: "MAP_007", _, _): "코드를 다시 확인해주세요"
        case .server(code: "MAP_005", _, _): "이미 참여 중인 지도예요"
        default: "지도에 참여하지 못했어요"
        }
    }

    /// 목록이 비거나 못 읽으면 `완료` 버튼이 사라진다. 하단 탭도 숨어 있어 편집을 빠져나갈 수 없게 된다.
    private func endEditingIfNothingToEdit(_ type: CollectionMapType) {
        guard type == uiState.selectedTab else { return }
        if case .loaded(let maps) = uiState.currentMaps, !maps.isEmpty { return }
        finishEditing()
    }

    /// 편집 중 서버를 오가는 동안 고른 목록을 잠근다. 실패는 안내로만 알리고 편집은 그대로 둔다.
    private func runEditTask<Value>(
        _ work: @escaping () async throws -> Value,
        onSuccess: @escaping (Value) -> Void
    ) {
        uiState.editing?.processing = true
        editTask = Task { [weak self] in
            do {
                let value = try await work()
                try Task.checkCancellation()
                self?.uiState.editing?.processing = false
                onSuccess(value)
            } catch {
                guard !(error is CancellationError), let self else { return }
                uiState.editing?.processing = false
                uiState.notice = MapDetailMessage.userMessage(for: error, fallback: MapDetailMessage.loadFailed)
            }
        }
    }

    private func load(_ type: CollectionMapType, keepCurrent: Bool = false) {
        loadTasks[type]?.cancel()
        requestedTabs.insert(type)
        if !keepCurrent || uiState.state(of: type) == .idle {
            uiState.setState(.loading, for: type)
        }
        // 저장 중인 순서가 있으면 끝난 뒤에 읽는다. 먼저 읽으면 바꾸기 전 순서가 화면을 덮는다.
        let orderSave = orderTask
        loadTasks[type] = Task { [weak self, repository] in
            defer {
                if !Task.isCancelled { self?.loadTasks[type] = nil }
            }
            do {
                await orderSave?.value
                let maps = try await repository.fetchMyMaps(type: type)
                try Task.checkCancellation()
                self?.uiState.setState(.loaded(maps), for: type)
                self?.endEditingIfNothingToEdit(type)
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                guard let self else { return }
                if keepCurrent, case .loaded = uiState.state(of: type) { return }
                uiState.setState(.failed("지도 목록을 불러오지 못했어요"), for: type)
                endEditingIfNothingToEdit(type)
            }
        }
    }
}
