import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MapMemberRepositoryTests {
    private final class Log: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [URLRequest] = []
        func add(_ request: URLRequest) { lock.withLock { items.append(request) } }
        var requests: [URLRequest] { lock.withLock { items } }
    }

    private func repository(_ log: Log, _ body: @escaping @Sendable (URLRequest) -> String) throws -> MapMemberRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.add(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body(request).utf8), response)
        }
        return MapMemberRepositoryImpl(client: client)
    }

    @Test func 멤버를_변환하고_이름이_없으면_알_수_없는_사용자로_채운다() async throws {
        let log = Log()
        let sut = try repository(log) { _ in
            #"""
            {"success":true,"data":{"memberCount":2,"members":[
            {"userId":1,"nickname":" 모아 ","profileImageUrl":"https://p","role":"OWNER","placeCount":3},
            {"userId":2,"nickname":" ","profileImageUrl":"","role":"NONE"}]}}
            """#
        }
        let members = try await sut.fetchMembers(mapID: 7)
        #expect(members == [
            MapMember(id: 1, name: "모아", imageURL: URL(string: "https://p"), role: .owner, placeCount: 3),
            MapMember(id: 2, name: "알 수 없는 사용자", imageURL: nil, role: .none, placeCount: nil)
        ])
        #expect(log.requests.first?.url?.path == "/api/v1/maps/7/members")
    }

    @Test func 권한_부여는_역할을_ADMIN_으로_PUT_한다() async throws {
        let log = Log()
        let sut = try repository(log) { _ in #"{"success":true,"data":{"mapId":7,"userId":2,"role":"ADMIN"}}"# }
        try await sut.grantAdmin(mapID: 7, userID: 2)
        let request = try #require(log.requests.first)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path == "/api/v1/maps/7/members/2/role")
        let json = try #require(try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: String])
        #expect(json == ["role": "ADMIN"])
    }
}
