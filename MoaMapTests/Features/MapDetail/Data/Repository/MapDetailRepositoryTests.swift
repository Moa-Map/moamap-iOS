import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MapDetailRepositoryTests {
    /// 경로마다 다른 응답을 준다. 없는 경로는 500.
    private func repository(
        responses: @escaping @Sendable (URLRequest) -> String?,
        inspect: @escaping @Sendable (URLRequest) -> Void = { _ in }
    ) throws -> MapDetailRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            inspect(request)
            let url = try #require(request.url)
            let body = responses(request)
            let response = try #require(HTTPURLResponse(url: url, statusCode: body == nil ? 500 : 200, httpVersion: nil, headerFields: nil))
            return (Data((body ?? #"{"success":false,"code":"COMMON_005"}"#).utf8), response)
        }
        return MapDetailRepositoryImpl(client: client)
    }

    private nonisolated static func query(_ request: URLRequest) -> [String: String] {
        let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func 지도_상세에_제작자_닉네임을_채워서_변환한다() async throws {
        let sut = try repository { request -> String? in
            switch request.url?.path {
            case "/api/v1/maps/7":
                return #"""
                {"success":true,"data":{"id":7,"name":"성수 카페","description":" ","imageUrl":"https://example.com/m.png",
                "type":"COMMUNITY","ownerId":3,"tags":["카페"," "],"memberCount":12,"placeCount":4,
                "joined":false,"personal":false,"myRole":"NONE","inviteCode":""}}
                """#
            case "/api/v1/users/profiles":
                #expect(Self.query(request) == ["ids": "3"])
                return #"{"success":true,"data":[{"id":3,"nickname":"모아"}]}"#
            default:
                return nil
            }
        }
        let map = try await sut.fetchMapDetail(mapID: 7)
        #expect(map == MapDetail(
            id: 7, title: "성수 카페", description: nil, imageURL: URL(string: "https://example.com/m.png"),
            ownerName: "모아", type: .community, role: .none, tags: ["카페"], memberCount: 12, placeCount: 4,
            joined: false, personal: false, inviteCode: nil
        ))
    }

    @Test func 제작자_조회가_실패해도_지도는_돌려준다() async throws {
        let sut = try repository { request in
            request.url?.path == "/api/v1/maps/7"
                ? #"{"success":true,"data":{"id":7,"name":"지도","type":"PRIVATE","ownerId":3,"myRole":"OWNER","joined":true,"personal":true}}"#
                : nil
        }
        let map = try await sut.fetchMapDetail(mapID: 7)
        #expect(map.ownerName == nil)
        #expect(map.type == .private)
        #expect(map.role == .owner)
        #expect(map.personal)
    }

    @Test func 장소는_마지막_페이지까지_이어_받는다() async throws {
        let sut = try repository { request in
            #expect(request.url?.path == "/api/v1/places")
            let query = Self.query(request)
            #expect(query["mapId"] == "7")
            #expect(query["size"] == "1000")
            return query["page"] == "0"
                ? #"{"success":true,"data":{"content":[{"id":1,"name":"카페","lat":37.5,"lng":127.0,"roadAddress":"성수이로 1","address":"성수동 1"}],"last":false}}"#
                : #"{"success":true,"data":{"content":[{"id":2,"name":"","lat":37.6,"lng":127.1,"address":"성수동 2","photoUrls":["","https://example.com/p.png"]},{"id":3,"name":"좌표 없음"}],"last":true}}"#
        }
        let places = try await sut.fetchPlaces(mapID: 7)
        #expect(places == [
            MapPlace(id: 1, name: "카페", address: "성수이로 1", latitude: 37.5, longitude: 127.0, photoURL: nil),
            MapPlace(id: 2, name: "이름 없는 장소", address: "성수동 2", latitude: 37.6, longitude: 127.1, photoURL: URL(string: "https://example.com/p.png"))
        ])
    }

    @Test func 빈_페이지가_오면_last_가_없어도_멈춘다() async throws {
        let pages = RequestCounter()
        let sut = try repository { _ in
            pages.increment()
            return #"{"success":true,"data":{"content":[],"last":false}}"#
        }
        #expect(try await sut.fetchPlaces(mapID: 7).isEmpty)
        #expect(pages.value == 1)
    }

    @Test func 참여는_POST_로_요청한다() async throws {
        let sut = try repository(responses: { _ in #"{"success":true,"data":{"id":7}}"# }) { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/api/v1/maps/7/join")
        }
        try await sut.joinMap(mapID: 7)
    }

    @Test func 상세_조회_오류를_전파한다() async throws {
        let sut = try repository { _ in nil }
        await #expect(throws: NetworkError.self) { try await sut.fetchMapDetail(mapID: 7) }
    }
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}
