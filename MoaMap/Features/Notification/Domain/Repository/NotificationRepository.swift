/// 내 알림. 로그인이 필요하다.
@MainActor
protocol NotificationRepository {
    /// 최신순 `page` 번째 쪽(0부터).
    func fetchNotifications(page: Int, size: Int) async throws -> NotificationPage
    /// 이미 읽은 알림이어도 성공한다.
    func markRead(id: Int64) async throws
    /// 안 읽은 알림이 없어도 성공한다.
    func markAllRead() async throws
}
