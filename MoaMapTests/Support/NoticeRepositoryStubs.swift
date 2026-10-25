import Foundation
@testable import MoaMap

@MainActor
final class NoticeRepositoryStub: NoticeRepository {
    nonisolated static func notice(_ id: Int64) -> Notice {
        Notice(id: id, title: "공지 \(id)", content: "본문 \(id)", createdAt: Date(timeIntervalSince1970: 0))
    }

    var page: (Int, Int) async throws -> NoticePage = { _, _ in NoticePage(notices: [NoticeRepositoryStub.notice(1)], isLast: true) }
    var detail: (Int64) async throws -> Notice = { NoticeRepositoryStub.notice($0) }
    private(set) var pageRequests: [(page: Int, size: Int)] = []

    func fetchNotices(page: Int, size: Int) async throws -> NoticePage {
        pageRequests.append((page, size))
        return try await self.page(page, size)
    }

    func fetchNotice(id: Int64) async throws -> Notice { try await detail(id) }
}

@MainActor
final class InquiryRepositoryStub: InquiryRepository {
    var send: () async throws -> Void = {}
    private(set) var sent: [(type: InquiryType, replyEmail: String, content: String)] = []

    func sendInquiry(type: InquiryType, replyEmail: String, content: String) async throws {
        sent.append((type, replyEmail, content))
        try await send()
    }
}
