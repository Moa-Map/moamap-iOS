nonisolated enum CollectionMapsState: Equatable, Sendable {
    case idle
    case loading
    case loaded([MyMap])
    case failed(String)
}

nonisolated struct CollectionUiState: Equatable, Sendable {
    var selectedTab: CollectionMapType = .community
    var community: CollectionMapsState = .idle
    var privateMaps: CollectionMapsState = .idle

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
