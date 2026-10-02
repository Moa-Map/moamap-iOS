import Testing
@testable import MoaMap

struct MapDetailRuleTests {
    private func map(
        type: MapType, role: MapRole = .none, joined: Bool = false, personal: Bool = false,
        memberCount: Int = 1, inviteCode: String? = nil
    ) -> MapDetail {
        MapDetail(
            id: 1, title: "지도", description: nil, imageURL: nil, ownerName: nil, type: type, role: role,
            tags: [], memberCount: memberCount, placeCount: 0, joined: joined, personal: personal, inviteCode: inviteCode
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

    @Test func 나가기_안내는_지도_종류와_역할을_따른다() {
        #expect(map(type: .community, role: .member, joined: true).leaveOutcome == .leave)
        #expect(map(type: .private, role: .member, joined: true).leaveOutcome == .leaveNeedsInviteCode)
        #expect(map(type: .private, role: .owner, joined: true).leaveOutcome == .deleteMap)
        #expect(map(type: .private, role: .owner, joined: true, memberCount: 2).leaveOutcome == nil)
        #expect(map(type: .community, role: .owner, joined: true).leaveOutcome == nil)
        #expect(map(type: .private, role: .owner, joined: true, personal: true).leaveOutcome == nil)
    }

    @Test func 지도_삭제는_혼자_남은_프라이빗_방장만_한다() {
        #expect(map(type: .private, role: .owner, joined: true).leavingDeletesMap)
        #expect(!map(type: .private, role: .owner, joined: true, personal: true).leavingDeletesMap)
        #expect(!map(type: .community, role: .owner, joined: true).leavingDeletesMap)
        #expect(!map(type: .private, role: .owner, joined: true, memberCount: 3).leavingDeletesMap)
    }

    @Test func 메뉴는_참여한_공식지도_외_지도에만_띄운다() {
        #expect(map(type: .community, role: .member, joined: true).showsMenu)
        #expect(!map(type: .official, role: .member, joined: true).showsMenu)
        #expect(!map(type: .community).showsMenu)
    }

    @Test func 초대코드는_참여한_프라이빗_지도에서만_꺼낸다() {
        #expect(map(type: .private, role: .member, joined: true, inviteCode: "ABC").shareableInviteCode == "ABC")
        #expect(map(type: .private, role: .owner, joined: true, personal: true, inviteCode: "ABC").shareableInviteCode == nil)
        #expect(map(type: .community, role: .member, joined: true, inviteCode: "ABC").shareableInviteCode == nil)
    }

    @Test func 장소_추가는_참여한_커뮤니티_프라이빗_지도만_연다() {
        #expect(map(type: .community, role: .member, joined: true).canAddPlace)
        #expect(map(type: .private, role: .member, joined: true).canAddPlace)
        #expect(!map(type: .official, role: .member, joined: true).canAddPlace)
        #expect(!map(type: .community).canAddPlace)
    }
}
