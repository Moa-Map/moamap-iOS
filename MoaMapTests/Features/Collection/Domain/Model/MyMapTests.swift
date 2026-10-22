import Testing
@testable import MoaMap

struct MyMapTests {
    private func map(role: MapRole, official: Bool = false) -> MyMap {
        MyMap(id: 1, title: "지도", imageURL: nil, memberCount: 1, placeCount: 0, official: official, personal: false, role: role)
    }

    @Test func 방장과_관리자만_역할_뱃지를_단다() {
        #expect(map(role: .owner).roleBadge == .owner)
        #expect(map(role: .admin).roleBadge == .admin)
        #expect(map(role: .member).roleBadge == nil)
        #expect(map(role: .none).roleBadge == nil)
    }

    @Test func 공식지도에는_역할_뱃지를_달지_않는다() {
        #expect(map(role: .owner, official: true).roleBadge == nil)
    }
}
