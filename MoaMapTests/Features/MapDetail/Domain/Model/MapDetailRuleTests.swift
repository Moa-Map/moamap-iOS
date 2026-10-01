import Testing
@testable import MoaMap

struct MapDetailRuleTests {
    private func map(type: MapType, role: MapRole = .none, joined: Bool = false, personal: Bool = false) -> MapDetail {
        MapDetail(
            id: 1, title: "지도", description: nil, imageURL: nil, ownerName: nil, type: type, role: role,
            tags: [], memberCount: 1, placeCount: 0, joined: joined, personal: personal, inviteCode: nil
        )
    }

    @Test(arguments: [(MapRole.owner, "방장"), (.admin, "관리자"), (.member, "멤버")])
    func 커뮤니티_지도는_역할을_배지로_보인다(role: MapRole, badge: String) {
        #expect(map(type: .community, role: role, joined: true).roleBadge == badge)
    }

    @Test func 프라이빗_공식_지도와_참여하지_않은_지도는_배지가_없다() {
        #expect(map(type: .private, role: .owner, joined: true).roleBadge == nil)
        #expect(map(type: .official, role: .member, joined: true).roleBadge == nil)
        #expect(map(type: .community).roleBadge == nil)
    }

    @Test func 참여하지_않은_공개_지도에만_참여하기를_띄운다() {
        #expect(map(type: .community).canJoin)
        #expect(map(type: .official).canJoin)
        #expect(!map(type: .community, joined: true).canJoin)
        #expect(!map(type: .private).canJoin)
        #expect(!map(type: .private, personal: true).canJoin)
    }
}
