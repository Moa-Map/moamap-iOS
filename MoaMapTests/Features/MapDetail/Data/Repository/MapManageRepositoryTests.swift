import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MapManageRepositoryTests {
    private final class Log: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [URLRequest] = []
        func add(_ request: URLRequest) { lock.withLock { items.append(request) } }
        var requests: [URLRequest] { lock.withLock { items } }
    }

    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    private func client(_ log: Log, _ body: @escaping @Sendable (URLRequest) -> String) throws -> APIClient {
        APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.add(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body(request).utf8), response)
        }
    }

    @Test func 활동_내역을_변환하고_모르는_종류는_버린다() async throws {
        let log = Log()
        let sut = MapActivityRepositoryImpl(client: try client(log) { _ in
            #"""
            {"success":true,"data":{"content":[
            {"type":"PLACE_ADDED","occurredAt":"2026-07-30T02:54:12","actorNickname":" ","placeId":1,"placeName":" 카페 "},
            {"type":"PLACE_DELETED","actorNickname":"모아","actorProfileImageUrl":"https://p"},
            {"type":"UNKNOWN"}]}}
            """#
        }, timeZone: seoul)
        let activities = try await sut.fetchActivities(mapID: 7)
        #expect(activities == [
            MapActivity(type: .placeAdded, occurredAt: Date(timeIntervalSince1970: 1_785_347_652), actorName: nil,
                        actorImageURL: nil, placeID: 1, placeName: "카페"),
            MapActivity(type: .placeRemoved, occurredAt: nil, actorName: "모아", actorImageURL: URL(string: "https://p"),
                        placeID: nil, placeName: nil)
        ])
        let query = log.requests.first?.url?.query ?? ""
        #expect(log.requests.first?.url?.path == "/api/v1/places/activities")
        #expect(query.contains("mapId=7"))
    }

    @Test func 등록_요청을_마지막_페이지까지_읽는다() async throws {
        let log = Log()
        let sut = PendingPlaceRepositoryImpl(client: try client(log) { request in
            request.url?.query?.contains("page=0") == true
                ? #"{"success":true,"data":{"content":[{"id":1,"name":"카페","createdByNickname":"모아"}],"last":false}}"#
                : #"{"success":true,"data":{"content":[{"id":2,"name":" "}],"last":true}}"#
        }, timeZone: seoul)
        let pending = try await sut.fetchPendingPlaces(mapID: 7)
        #expect(pending == [
            PendingPlace(id: 1, placeName: "카페", requesterName: "모아", requesterImageURL: nil, requestedAt: nil),
            PendingPlace(id: 2, placeName: nil, requesterName: nil, requesterImageURL: nil, requestedAt: nil)
        ])
        #expect(log.requests.count == 2)
    }

    @Test func 수락과_거절은_PATCH_로_보낸다() async throws {
        let log = Log()
        let sut = PendingPlaceRepositoryImpl(client: try client(log) { _ in #"{"success":true,"data":{"id":3}}"# }, timeZone: seoul)
        try await sut.approve(placeID: 3)
        try await sut.reject(placeID: 4)
        #expect(log.requests.map(\.httpMethod) == ["PATCH", "PATCH"])
        #expect(log.requests.map { $0.url?.path } == ["/api/v1/places/3/approve", "/api/v1/places/4/reject"])
    }
}
