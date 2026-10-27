@MainActor
protocol BlockRepository {
    /// 최근에 차단한 사람이 앞에 온다. 탈퇴한 사람은 빠진다.
    func fetchBlockedUsers() async throws -> [BlockedUser]
    /// 이미 차단한 사람이어도 성공한다.
    func block(userID: Int64) async throws
    /// 차단하지 않은 사람이어도 성공한다.
    func unblock(userID: Int64) async throws
}
