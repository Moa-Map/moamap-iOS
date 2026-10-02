import Foundation
import Testing
@testable import MoaMap

@MainActor
struct PersonalMapRepositoryTests {
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var bodies: [Data] = []
        func record(_ body: Data?) { lock.withLock { if let body { bodies.append(body) } } }
        var posted: [Data] { lock.withLock { bodies } }
    }

    private func repository(_ responses: @escaping @Sendable (URLRequest) -> String?, recorder: Recorder) throws -> PersonalMapRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            if request.httpMethod == "POST" { recorder.record(request.httpBody) }
            let url = try #require(request.url)
            let body = responses(request)
            let response = try #require(HTTPURLResponse(url: url, statusCode: body == nil ? 500 : 200, httpVersion: nil, headerFields: nil))
            return (Data((body ?? #"{"success":false,"code":"COMMON_005"}"#).utf8), response)
        }
        return PersonalMapRepositoryImpl(client: client)
    }

    @Test func 장소를_다시_읽어_나만의_지도에_그대로_등록한다() async throws {
        let recorder = Recorder()
        let sut = try repository({ request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/places/3"):
                return #"""
                {"success":true,"data":{"id":3,"name":"카페","address":"성수동 1","roadAddress":" ","lat":37.5,"lng":127.0,
                "category":"음식점 > 카페","kakaoPlaceId":"999","sourceType":"","description":"좋아요","tags":["조용"],"photoUrls":["","https://p"]}}
                """#
            case ("GET", "/api/v1/maps/me"):
                return #"{"success":true,"data":{"content":[{"id":10,"personal":false},{"id":11,"personal":true}],"last":true}}"#
            case ("POST", "/api/v1/places"):
                return #"{"success":true,"data":{"id":50}}"#
            default:
                return nil
            }
        }, recorder: recorder)
        try await sut.addPlace(placeID: 3)
        let body = try #require(recorder.posted.first)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["mapId"] as? Int == 11)
        #expect(json["kakaoPlaceId"] as? String == "999")
        #expect(json["sourceType"] as? String == "KAKAO_SEARCH")
        #expect(json["roadAddress"] == nil)
        #expect(json["photoUrls"] as? [String] == ["https://p"])
        #expect(json["tags"] as? [String] == ["조용"])
    }

    @Test func 나만의_지도가_없으면_등록하지_않는다() async throws {
        let recorder = Recorder()
        let sut = try repository({ request in
            switch request.url?.path {
            case "/api/v1/places/3":
                return #"{"success":true,"data":{"id":3,"name":"카페","lat":37.5,"lng":127.0,"kakaoPlaceId":"999"}}"#
            case "/api/v1/maps/me":
                return #"{"success":true,"data":{"content":[{"id":10,"personal":false}],"last":true}}"#
            default:
                return nil
            }
        }, recorder: recorder)
        await #expect(throws: PersonalMapNotFoundError.self) { try await sut.addPlace(placeID: 3) }
        #expect(recorder.posted.isEmpty)
    }
}
