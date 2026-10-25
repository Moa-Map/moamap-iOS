import Foundation

nonisolated struct NoticePageResponse: Decodable, Sendable {
    let content: [NoticeResponse]?
    let last: Bool?
}

/// 목록에도 본문 전체가 온다. 미리보기 자르기는 화면이 한다.
nonisolated struct NoticeResponse: Decodable, Sendable {
    let noticeId: Int64
    let title: String?
    let content: String?
    /// `Z` 가 붙은 UTC 시각.
    let createdAt: String?

    func toDomain() -> Notice {
        Notice(
            id: noticeId,
            title: title ?? "",
            content: content ?? "",
            createdAt: ServerDateTime.parse(createdAt, timeZone: .gmt)
        )
    }
}
