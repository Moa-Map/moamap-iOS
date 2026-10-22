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
struct TermsRepositoryTests {
    private func repository(body: String, statusCode: Int = 200, log: RequestLog = RequestLog()) throws -> TermsRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.append(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return TermsRepositoryImpl(client: client)
    }

    @Test func 약관_목록을_순서대로_변환한다() async throws {
        let log = RequestLog()
        let sut = try repository(body: #"""
        {"success":true,"data":[
          {"termId":1,"code":"SERVICE","title":"서비스 이용약관","version":"1.0","kind":"REQUIRED"},
          {"termId":3,"code":"POLICY","title":"개인정보 처리방침","version":"1.0","kind":"VIEW_ONLY"}
        ]}
        """#, log: log)

        let terms = try await sut.fetchTerms()

        #expect(terms == [
            Term(id: 1, code: "SERVICE", title: "서비스 이용약관", version: "1.0", kind: .required),
            Term(id: 3, code: "POLICY", title: "개인정보 처리방침", version: "1.0", kind: .viewOnly)
        ])
        #expect(log.requests.first?.httpMethod == "GET")
        #expect(log.requests.first?.url?.path == "/api/v1/terms")
    }

    @Test func 약관_전문을_변환한다() async throws {
        let log = RequestLog()
        let sut = try repository(body: #"""
        {"success":true,"data":{"termId":3,"code":"POLICY","title":"개인정보 처리방침","version":"1.0","kind":"VIEW_ONLY","active":true,"content":"# 제1조\n본문"}}
        """#, log: log)

        let detail = try await sut.fetchTerm(id: 3)

        #expect(detail.term.title == "개인정보 처리방침")
        #expect(detail.term.kind == .viewOnly)
        #expect(detail.isActive)
        #expect(detail.content == "# 제1조\n본문")
        #expect(log.requests.first?.url?.path == "/api/v1/terms/3")
    }

    @Test func 내_동의_상태를_변환한다() async throws {
        let log = RequestLog()
        let sut = try repository(body: #"""
        {"success":true,"data":{"needsAgreement":true,"pendingTerms":[{"termId":2,"code":"AGE","title":"만 14세 이상 확인","version":"1.0","kind":"REQUIRED"}]}}
        """#, log: log)

        let status = try await sut.fetchAgreementStatus()

        #expect(status.needsAgreement)
        #expect(status.pendingTerms.map(\.id) == [2])
        #expect(log.requests.first?.httpMethod == "GET")
        #expect(log.requests.first?.url?.path == "/api/v1/terms/agreements/me")
    }

    @Test func 동의는_약관_ID_를_POST_로_보낸다() async throws {
        let log = RequestLog()
        let sut = try repository(body: #"{"success":true,"data":{"needsAgreement":false,"pendingTerms":[]}}"#, log: log)

        let status = try await sut.agree(termIDs: [1, 2])

        #expect(status == TermAgreementStatus(needsAgreement: false, pendingTerms: []))
        let request = try #require(log.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/v1/terms/agreements")
        let data = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(body["termIds"] as? [Int] == [1, 2])
    }

    @Test(arguments: [
        ("USER_020", 404), ("USER_021", 400), ("USER_022", 400), ("USER_023", 409)
    ])
    func 서버_오류_코드를_그대로_전달한다(code: String, status: Int) async throws {
        let sut = try repository(
            body: #"{"success":false,"data":null,"error":{"code":"\#(code)","status":\#(status),"message":"원문"}}"#,
            statusCode: status
        )

        await #expect(throws: NetworkError.server(code: code, statusCode: status, message: "원문")) {
            _ = try await sut.agree(termIDs: [1])
        }
    }
}
