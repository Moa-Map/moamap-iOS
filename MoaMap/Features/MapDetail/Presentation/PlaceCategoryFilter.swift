import Foundation

/// 장소 목록 위의 카테고리 칩. 카카오 분류에 없는 장소도 찾을 수 있게 기타를 둔다.
nonisolated enum PlaceCategoryFilter: Hashable, Sendable {
    case all
    case group(PlaceCategoryGroup)
    case other

    var label: String {
        switch self {
        case .all: "전체"
        case .group(let group): group.label
        case .other: "기타"
        }
    }

    func matches(_ place: MapPlace) -> Bool {
        switch self {
        case .all: true
        case .group(let group): PlaceCategoryGroup(categoryPath: place.category) == group
        case .other: PlaceCategoryGroup(categoryPath: place.category) == nil
        }
    }

    /// 전체 뒤에 이 지도에 실제로 있는 카테고리만 붙인다. 순서는 고정이라 장소가 늘어도 칩이 자리를 바꾸지 않는다.
    static func available(in places: [MapPlace]) -> [PlaceCategoryFilter] {
        let groups = places.map { PlaceCategoryGroup(categoryPath: $0.category) }
        let present = Set(groups.compactMap { $0 })
        var filters: [PlaceCategoryFilter] = [.all]
        filters += PlaceCategoryGroup.allCases.filter(present.contains).map(PlaceCategoryFilter.group)
        if groups.contains(nil) { filters.append(.other) }
        return filters
    }
}

nonisolated extension Array where Element == MapPlace {
    /// 카테고리와 이름 검색을 함께 적용한다. 지도 마커와 목록이 같은 결과를 본다.
    /// 주소는 보지 않는다. "서울" 같은 걸 치면 거른 티가 안 난다.
    func filtered(by category: PlaceCategoryFilter, query: String) -> [MapPlace] {
        let keyword = query.trimmingCharacters(in: .whitespaces)
        return filter { place in
            category.matches(place) && (keyword.isEmpty || place.name.localizedCaseInsensitiveContains(keyword))
        }
    }
}
