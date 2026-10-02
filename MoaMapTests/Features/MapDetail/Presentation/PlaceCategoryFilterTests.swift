import Testing
@testable import MoaMap

struct PlaceCategoryFilterTests {
    private func place(_ id: Int64, _ name: String, category: String) -> MapPlace {
        MapPlace(id: id, name: name, address: "서울", latitude: 0, longitude: 0, photoURL: nil, category: category)
    }

    @Test func 칩은_전체_뒤에_있는_카테고리만_고정_순서로_붙이고_분류_밖은_기타로_묶는다() {
        let places = [
            place(1, "카페", category: "음식점 > 카페 > 커피전문점"),
            place(2, "마트", category: "가정,생활 > 대형마트"),
            place(3, "모름", category: ""),
            place(4, "카페2", category: "음식점 > 카페")
        ]
        #expect(PlaceCategoryFilter.available(in: places) == [.all, .group(.mart), .group(.cafe), .other])
    }

    @Test func 장소가_없어도_전체_칩은_남는다() {
        #expect(PlaceCategoryFilter.available(in: []) == [.all])
    }

    @Test func 카테고리와_이름_검색을_함께_적용한다() {
        let places = [
            place(1, "Coffee 나무", category: "음식점 > 카페"),
            place(2, "커피 식당", category: "음식점 > 한식"),
            place(3, "기타 커피", category: "")
        ]
        #expect(places.filtered(by: .group(.cafe), query: "").map(\.id) == [1])
        #expect(places.filtered(by: .all, query: " coffee ").map(\.id) == [1])
        #expect(places.filtered(by: .other, query: "커피").map(\.id) == [3])
        #expect(places.filtered(by: .group(.restaurant), query: "커피").map(\.id) == [2])
    }

    @Test func 검색은_주소를_보지_않는다() {
        #expect([place(1, "카페", category: "")].filtered(by: .all, query: "서울").isEmpty)
    }
}
