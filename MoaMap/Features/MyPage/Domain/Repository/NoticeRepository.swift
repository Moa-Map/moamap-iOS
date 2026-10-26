@MainActor
protocol NoticeRepository {
    /// 최신 등록순 `page` 번째 쪽(0부터).
    func fetchNotices(page: Int, size: Int) async throws -> NoticePage
    /// 지워졌거나 없는 공지는 404 `USER_011`.
    func fetchNotice(id: Int64) async throws -> Notice
}
