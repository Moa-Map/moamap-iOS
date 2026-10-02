@MainActor
protocol MapMemberRepository {
    /// 서버가 준 순서 그대로 전부 돌려준다.
    func fetchMembers(mapID: Int64) async throws -> [MapMember]
    /// 일반 멤버를 관리자로 올린다. 방장만 할 수 있다.
    func grantAdmin(mapID: Int64, userID: Int64) async throws
}
