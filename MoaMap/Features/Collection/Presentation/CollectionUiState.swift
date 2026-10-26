nonisolated enum CollectionMapsState: Equatable, Sendable {
    case idle
    case loading
    case loaded([MyMap])
    case failed(String)
}

nonisolated struct JoinMapEditing: Equatable, Sendable {
    var code = ""
    var submitting = false
    var errorMessage: String?

    /// 초대 코드는 항상 여섯 자리다.
    static let codeLength = 6

    var canSubmit: Bool { code.count == Self.codeLength && !submitting }
}

nonisolated enum JoinMapState: Equatable, Sendable {
    case hidden
    case editing(JoinMapEditing)
}

/// 모음 편집. 고른 지도에서 나가거나 하나를 골라 정보를 고친다.
nonisolated struct CollectionEditing: Equatable, Sendable {
    var selectedIDs: Set<Int64> = []
    /// 고른 지도의 역할을 확인하거나 나가는 중. 두 번 눌러도 서버에는 한 번만 간다.
    var processing = false

    var canLeave: Bool { !selectedIDs.isEmpty && !processing }
}

nonisolated enum CollectionEditDialog: Equatable, Sendable {
    /// 서버가 방장의 탈퇴를 막는다. 하나라도 섞이면 아무 지도에서도 나가지 않는다.
    case ownerCannotLeave
    case confirmLeave(count: Int, outcome: LeaveOutcome)
}

nonisolated struct CollectionUiState: Equatable, Sendable {
    var selectedTab: CollectionMapType = .community
    var community: CollectionMapsState = .idle
    var privateMaps: CollectionMapsState = .idle
    var join: JoinMapState = .hidden
    var editing: CollectionEditing?
    var editDialog: CollectionEditDialog?
    /// 한 번 보여주고 지우는 안내.
    var notice: String?

    var currentMaps: CollectionMapsState { state(of: selectedTab) }

    func state(of type: CollectionMapType) -> CollectionMapsState {
        type == .community ? community : privateMaps
    }

    mutating func setState(_ state: CollectionMapsState, for type: CollectionMapType) {
        switch type {
        case .community: community = state
        case .private: privateMaps = state
        }
    }
}

/// 개인 지도는 전체 목록에 중복 표시하지 않는다.
nonisolated struct PrivateMapSections: Equatable, Sendable {
    let personal: [MyMap]
    let others: [MyMap]

    init(maps: [MyMap]) {
        personal = maps.filter(\.personal)
        others = maps.filter { !$0.personal }
    }
}
