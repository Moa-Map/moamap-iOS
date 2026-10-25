import Foundation
import Testing
@testable import MoaMap

private final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { items } }
    func append(_ request: URLRequest) { lock.withLock { items.append(request) } }
}

@MainActor
struct NoticeInquiryRepositoryTests {
    private func client(body: String, status: Int = 200, log: RequestLog) throws -> APIClient {
        APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.append(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
    }

    @Test func 공지_목록을_쪽_번호와_크기로_받고_UTC_시각을_읽는다() async throws {
        let log = RequestLog()
        let sut = NoticeRepositoryImpl(client: try client(body: #"""
        {"success":true,"data":{"content":[
          {"noticeId":3,"title":"점검","content":"본문","createdAt":"2026-10-20T15:00:00Z"},
          {"noticeId":2,"title":null,"content":null,"createdAt":"잘못된 값"}
        ],"last":false}}
        """#, log: log))
        let page = try await sut.fetchNotices(page: 1, size: 20)
        #expect(page.isLast == false)
        #expect(page.notices == [
            Notice(id: 3, title: "점검", content: "본문", createdAt: Date(timeIntervalSince1970: 1_792_508_400)),
            Notice(id: 2, title: "", content: "", createdAt: nil)
        ])
        let url = try #require(log.requests.first?.url)
        #expect(url.path == "/api/v1/notices")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(query == [URLQueryItem(name: "page", value: "1"), URLQueryItem(name: "size", value: "20")])
    }

    @Test func 빈_쪽은_끝으로_본다() async throws {
        let sut = NoticeRepositoryImpl(client: try client(body: #"{"success":true,"data":{"content":[],"last":false}}"#, log: RequestLog()))
        #expect(try await sut.fetchNotices(page: 3, size: 20).isLast)
    }

    @Test func 공지_한_건을_받는다() async throws {
        let log = RequestLog()
        let sut = NoticeRepositoryImpl(client: try client(
            body: #"{"success":true,"data":{"noticeId":7,"title":"제목","content":"본문","createdAt":"2026-10-20T15:00:00Z"}}"#, log: log
        ))
        #expect(try await sut.fetchNotice(id: 7).title == "제목")
        #expect(log.requests.first?.url?.path == "/api/v1/notices/7")
    }

    @Test func 지워진_공지는_404_를_던진다() async throws {
        let sut = NoticeRepositoryImpl(client: try client(
            body: #"{"success":false,"error":{"code":"USER_011","status":404,"message":"없음"}}"#, status: 404, log: RequestLog()
        ))
        await #expect(throws: NetworkError.server(code: "USER_011", statusCode: 404, message: "없음")) {
            try await sut.fetchNotice(id: 7)
        }
    }

    @Test func 문의는_서버_유형값과_공백을_뗀_이메일로_보낸다() async throws {
        let log = RequestLog()
        let sut = InquiryRepositoryImpl(client: try client(body: #"{"success":true,"data":{"inquiryId":1}}"#, log: log))
        try await sut.sendInquiry(type: .report, replyEmail: "  moa@example.com \n", content: " 신고합니다 ")
        let request = try #require(log.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/v1/inquiries")
        let data = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body == ["type": "REPORT", "replyEmail": "moa@example.com", "content": "신고합니다"])
    }

    @Test func 문의_유형은_화면_순서대로_서버_값을_쓴다() {
        #expect(InquiryType.allCases.map(\.rawValue) == ["SERVICE", "TECHNICAL", "ACCOUNT", "REPORT", "PARTNERSHIP", "OTHER"])
        #expect(InquiryType.allCases.map(\.label) == ["서비스 이용 문제", "기술적 문제", "계정 관련", "신고 및 제재", "제휴 문의", "기타"])
    }
}
