import Foundation
import Testing
@testable import MoaMap

@MainActor
struct RestroomRepositoryTests {
    private func repository(body: String, inspect: @escaping @Sendable (URLRequest) -> Void = { _ in }) throws -> RestroomRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            inspect(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return RestroomRepositoryImpl(client: client)
    }

    private nonisolated static func query(_ request: URLRequest) -> [String: String] {
        let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func 범위의_남서_북동_꼭짓점으로_요청하고_변환한다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"restrooms":[
          {"id":6573,"name":"명달근린공원","lat":37.498295,"lng":127.021134,"category":"공중화장실"},
          {"id":1,"name":" ","lat":37.5,"lng":127.0},
          {"id":2,"name":"좌표 없음"}
        ],"truncated":true}}
        """#) { request in
            #expect(request.url?.path == "/api/v1/maps/official/restrooms")
            #expect(Self.query(request) == ["swLat": "37.495", "swLng": "127.02", "neLat": "37.505", "neLng": "127.035"])
        }
        let result = try await sut.fetchRestrooms(in: ViewportBounds(south: 37.495, west: 127.02, north: 37.505, east: 127.035))
        #expect(result == RestroomMarkers(restrooms: [
            RestroomMarker(id: 6573, name: "명달근린공원", latitude: 37.498295, longitude: 127.021134, category: "공중화장실"),
            RestroomMarker(id: 1, name: "이름 없는 화장실", latitude: 37.5, longitude: 127.0, category: nil)
        ], truncated: true))
    }

    @Test func 상세는_도로명_주소를_먼저_쓰고_빈_칸_수는_0으로_채운다() async throws {
        let sut = try repository(body: #"""
        {"success":true,"data":{"id":6573,"name":"시청역","category":"공중화장실","roadAddress":" ","lotAddress":"서울 중구 태평로1가 31",
         "maleToilet":6,"maleUrinal":5,"femaleToilet":15,"openHours":"정시","openHoursDetail":"05:00~24:00",
         "diaperTable":true,"managerOrg":"서울교통공사","dataRefDate":"2026-09-01"}}
        """#) { request in
            #expect(request.url?.path == "/api/v1/maps/official/restrooms/6573")
        }
        let detail = try await sut.fetchRestroom(id: 6573)
        #expect(detail == RestroomDetail(
            id: 6573, name: "시청역", category: "공중화장실", address: "서울 중구 태평로1가 31",
            openHours: "정시", openHoursDetail: "05:00~24:00",
            maleToilet: 6, maleUrinal: 5, maleDisabledToilet: 0, maleDisabledUrinal: 0, maleChildToilet: 0, maleChildUrinal: 0,
            femaleToilet: 15, femaleDisabledToilet: 0, femaleChildToilet: 0,
            diaperTable: true, emergencyBell: false, entranceCctv: false,
            managerOrg: "서울교통공사", phone: nil, dataRefDate: "2026-09-01"
        ))
    }
}
