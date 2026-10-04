import Foundation
import Testing
@testable import MoaMap

@MainActor
struct FootTrafficRepositoryTests {
    private func repository(respond: @escaping @Sendable (String) -> String) throws -> FootTrafficRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(respond(url.path).utf8), response)
        }
        return FootTrafficRepositoryImpl(client: client)
    }

    @Test func 지역과_혼잡도를_지역_코드로_합친다() async throws {
        let sut = try repository { path in
            switch path {
            case "/api/v1/maps/official/foot-traffic/areas":
                #"""
                {"success":true,"data":[
                  {"footTrafficAreaCd":"POI038","areaNm":"신도림역","lat":37.509021,"lng":126.890130,
                   "boundary":{"type":"Polygon","coordinates":[[[126.89,37.50],[126.90,37.50],[126.90,37.51],[126.89,37.50]]]}},
                  {"footTrafficAreaCd":"POI001","areaNm":"강남역","lat":37.4979,"lng":127.0276}
                ]}
                """#
            case "/api/v1/maps/official/foot-traffic/congestion":
                #"""
                {"success":true,"data":[
                  {"footTrafficAreaCd":"POI038","congestLvl":"붐빔","congestMsg":"사람이 많아요","ppltnMin":32000,"ppltnMax":34000,
                   "maleRate":44.1,"femaleRate":55.9,"ppltnRate20":31.6,"ppltnRate30":20.0,"ppltnRate70":1.2}
                ]}
                """#
            default:
                ""
            }
        }
        let areas = try await sut.fetchDensityAreas()
        #expect(areas.map(\.code) == ["POI038", "POI001"])
        #expect(areas[0].name == "신도림역")
        #expect(areas[0].boundary != nil)
        #expect(areas[0].congestion == AreaCongestion(
            level: .busy, message: "사람이 많아요", populationMin: 32000, populationMax: 34000,
            ageRates: [.twenties: 31.6, .thirties: 20.0, .seventiesUp: 1.2], maleRate: 44.1, femaleRate: 55.9
        ))
        #expect(areas[1].boundary == nil)
        #expect(areas[1].congestion == nil)
    }

    @Test func 코드_이름_좌표가_없는_지역은_버리고_깨진_경계는_없는_것으로_본다() async throws {
        let sut = try repository { path in
            path.hasSuffix("/areas")
                ? #"""
                {"success":true,"data":[
                  {"areaNm":"코드 없음","lat":37.5,"lng":127.0},
                  {"footTrafficAreaCd":"A","lat":37.5,"lng":127.0},
                  {"footTrafficAreaCd":"B","areaNm":"좌표 없음"},
                  {"footTrafficAreaCd":"C","areaNm":"경계 깨짐","lat":37.5,"lng":127.0,"boundary":{"type":"Polygon"}}
                ]}
                """#
                : #"{"success":true,"data":[]}"#
        }
        let areas = try await sut.fetchDensityAreas()
        #expect(areas.map(\.code) == ["C"])
        #expect(areas[0].boundary == nil)
    }
}
