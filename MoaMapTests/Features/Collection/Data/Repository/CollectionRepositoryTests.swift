import Foundation
import Testing
@testable import MoaMap

@MainActor
struct CollectionRepositoryTests {
    private func repository(body: String, inspect: @escaping @Sendable (URLRequest) -> Void = { _ in }) throws -> CollectionRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            inspect(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return CollectionRepositoryImpl(client: client)
    }

    @Test(arguments: [CollectionMapType.community, .private])
    func 참여한_지도를_유형별로_20개_조회한다(type: CollectionMapType) async throws {
        let sut = try repository(body: #"{"success":true,"data":{"content":[]}}"#) { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/api/v1/maps/me")
            let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
            let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
            #expect(query == ["type": type == .community ? "COMMUNITY" : "PRIVATE", "size": "20"])
        }
        #expect(try await sut.fetchMyMaps(type: type).isEmpty)
    }

    @Test func 개인지도_구분과_카드_정보를_보존한다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"content":[
          {"id":1,"name":"나만의 지도","type":"PRIVATE","personal":true,"memberCount":1,"placeCount":4,"imageUrl":"https://example.com/map.png"},
          {"id":2,"name":"친구들과","type":"PRIVATE","personal":false,"memberCount":3,"placeCount":2}
        ]}}
        """#)
        let maps = try await sut.fetchMyMaps(type: .private)
        #expect(maps == [
            MyMap(id: 1, title: "나만의 지도", imageURL: URL(string: "https://example.com/map.png"), memberCount: 1, placeCount: 4, official: false, personal: true),
            MyMap(id: 2, title: "친구들과", imageURL: nil, memberCount: 3, placeCount: 2, official: false, personal: false)
        ])
    }

    @Test func 누락된_선택값과_빈_이름에_기본값을_적용한다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"content":[{"id":1},{"id":2,"name":"  ","imageUrl":"  "}]}}
        """#)
        let maps = try await sut.fetchMyMaps(type: .community)
        #expect(maps.map(\.title) == ["이름 없는 지도", "이름 없는 지도"])
        #expect(maps.allSatisfy { $0.imageURL == nil && $0.memberCount == 0 && $0.placeCount == 0 && !$0.personal })
    }

    @Test func 서버_오류를_전파한다() async throws {
        let sut = try repository(body: #"{"success":false,"error":{"code":"COMMON_005","status":500}}"#)
        await #expect(throws: NetworkError.server(code: "COMMON_005", statusCode: 500)) {
            try await sut.fetchMyMaps(type: .community)
        }
    }

    @Test func 요청_취소를_전파한다() async throws {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { _ in
            throw CancellationError()
        }
        let sut = CollectionRepositoryImpl(client: client)
        await #expect(throws: CancellationError.self) {
            try await sut.fetchMyMaps(type: .private)
        }
    }
}
