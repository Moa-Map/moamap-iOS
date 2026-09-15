/// 토큰 갱신으로 바뀌지 않는 사용자 신원. 세션 만료 시 함께 정리한다.
nonisolated protocol CurrentUserStore: Sendable {
    func load() throws -> Int64?
    func save(userId: Int64) throws
    func clear() throws
}
