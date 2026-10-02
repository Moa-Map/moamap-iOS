import Foundation
import Testing
@testable import MoaMap

@MainActor
struct OfficialMapRepositoryTests {
    private func repository(body: String, inspect: @escaping @Sendable (URLRequest) -> Void = { _ in }) throws -> OfficialMapRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            inspect(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return OfficialMapRepositoryImpl(client: client)
    }

    @Test func 공식지도_목록을_첫_20개로_요청하고_변환한다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"content":[
          {"id":6,"name":"화장실 위치","description":"공공데이터 기반 공중화장실 위치","imageUrl":"https://example.com/a.png","type":"OFFICIAL","joined":true},
          {"id":7,"name":"공원","imageUrl":""}
        ],"last":true}}
        """#) { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/api/v1/maps/official")
            #expect(request.url?.query == "size=20")
        }
        let maps = try await sut.fetchOfficialMaps()
        #expect(maps == [
            OfficialMap(id: 6, title: "화장실 위치", description: "공공데이터 기반 공중화장실 위치", imageURL: URL(string: "https://example.com/a.png"), joined: true),
            OfficialMap(id: 7, title: "공원", description: "", imageURL: nil, joined: false)
        ])
    }

    @Test func 식별자가_없으면_버리고_이름이_없으면_자리를_채운다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"content":[{"name":"식별자 없음"},{"id":2,"name":" "},{"id":3}],"last":true}}
        """#)
        let maps = try await sut.fetchOfficialMaps()
        #expect(maps.map(\.id) == [2, 3])
        #expect(maps.map(\.title) == ["이름 없는 지도", "이름 없는 지도"])
    }
}
