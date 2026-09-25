import Foundation
import Testing
@testable import MoaMap

@MainActor
struct ExploreRepositoryTests {
    private func repository(body: String, inspect: @escaping @Sendable (URLRequest) -> Void = { _ in }) throws -> ExploreRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            inspect(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return ExploreRepositoryImpl(client: client)
    }

    private nonisolated static func query(_ request: URLRequest) -> [String: String] {
        let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func 커뮤니티_지도_목록을_정렬과_페이지로_요청하고_변환한다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"content":[
          {"id":5,"name":"분좋카","imageUrl":null,"tags":["카페"],"memberCount":3,"placeCount":2},
          {"id":4,"name":"카공족","imageUrl":"https://example.com/a.png","memberCount":1,"placeCount":5}
        ],"page":1,"size":2,"last":false}}
        """#) { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/api/v1/maps")
            #expect(Self.query(request) == ["sort": "LATEST", "page": "1", "size": "2"])
        }
        let page = try await sut.fetchCommunityMaps(sort: .latest, page: 1, size: 2)
        #expect(page.isLast == false)
        #expect(page.maps == [
            MapSummary(id: 5, title: "분좋카", imageURL: nil, tags: ["카페"], memberCount: 3, placeCount: 2),
            MapSummary(id: 4, title: "카공족", imageURL: URL(string: "https://example.com/a.png"), tags: [], memberCount: 1, placeCount: 5)
        ])
    }

    @Test func 식별자나_이름이_없는_지도는_버린다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"content":[{"name":"이름만"},{"id":2,"name":""},{"id":3,"name":"정상"}],"last":true}}
        """#)
        let page = try await sut.fetchCommunityMaps(sort: .popular, page: 0, size: 20)
        #expect(page.maps.map(\.id) == [3])
    }

    @Test func last_가_없으면_마지막_페이지로_본다() async throws {
        let sut = try repository(body: #"{"success":true,"data":{"content":[]}}"#)
        let page = try await sut.fetchCommunityMaps(sort: .popular, page: 0, size: 20)
        #expect(page.isLast)
    }

    @Test func 추천_지도는_장소_수_없이_변환한다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":[{"id":4,"name":"카공족","tags":["공부"],"memberCount":3,"reason":"지금 많이 찾는 지도예요"}]}
        """#) { request in
            #expect(request.url?.path == "/api/v1/maps/recommendations")
            #expect(Self.query(request) == ["size": "10"])
        }
        let maps = try await sut.fetchRecommendedMaps(size: 10)
        #expect(maps == [MapSummary(id: 4, title: "카공족", imageURL: nil, tags: ["공부"], memberCount: 3, placeCount: nil)])
    }

    @Test(arguments: [
        (#"{"nickname":"  모아  "}"#, "모아" as String?),
        (#"{"nickname":"   "}"#, nil),
        (#"{}"#, nil)
    ])
    func 닉네임을_정리해서_돌려준다(data: String, expected: String?) async throws {
        let sut = try repository(body: "{\"success\":true,\"data\":\(data)}") { request in
            #expect(request.url?.path == "/api/v1/users/me")
        }
        #expect(try await sut.fetchMyNickname() == expected)
    }

    @Test func 서버_오류를_전파한다() async throws {
        let sut = try repository(body: #"{"success":false,"error":{"code":"MAP_001","status":400}}"#)
        await #expect(throws: NetworkError.server(code: "MAP_001", statusCode: 400)) {
            try await sut.fetchRecommendedMaps(size: 10)
        }
    }
}
