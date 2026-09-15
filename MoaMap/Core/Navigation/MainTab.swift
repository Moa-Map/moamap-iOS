nonisolated enum MainTab: String, CaseIterable, Identifiable {
    case explore
    case collection

    var id: Self { self }

    var title: String {
        switch self {
        case .explore: "탐색"
        case .collection: "모음"
        }
    }
}
